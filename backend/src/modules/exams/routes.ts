import { Router } from "express";
import { z } from "zod";
import { db, isDbConfigured } from "../../config/db.js";
import { requireAuth } from "../../middleware/auth.js";
import { requireRole } from "../../middleware/rbac.js";
import { asyncHandler } from "../../utils/asyncHandler.js";
import { HttpError } from "../../utils/httpError.js";

export const examsRouter = Router();
examsRouter.use(requireAuth);

// Helper to get Supabase client safely
const getDb = () => {
  if (!isDbConfigured()) {
    throw new HttpError(503, "Database not configured: set SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY in .env");
  }
  return db();
};

// =====================================================================
// 1. DASHBOARD KPIS (ADMIN, FACULTY, STUDENT)
// =====================================================================
examsRouter.get(
  "/dashboard",
  requireRole("ADMIN", "FACULTY", "STUDENT"),
  asyncHandler(async (_req, res) => {
    const supabase = getDb();

    // Fetch all exams
    const { data: exams, error: examErr } = await supabase
      .from("exam")
      .select("exam_id, exam_name, exam_type, semester_id, sem_no, start_date, end_date, status")
      .order("start_date", { ascending: false });

    if (examErr) throw new HttpError(500, examErr.message);

    const now = new Date().toISOString().split("T")[0];

    const totalExams = exams?.length ?? 0;
    const upcomingExams = exams?.filter((e) => (e.status === "SCHEDULED" || e.status === "REGISTRATION_OPEN") && e.start_date >= now).length ?? 0;
    const ongoingExams = exams?.filter((e) => e.status === "ONGOING" || (e.start_date <= now && e.end_date >= now && e.status !== "COMPLETED" && e.status !== "RESULTS_PUBLISHED")).length ?? 0;
    const completedExams = exams?.filter((e) => e.status === "COMPLETED" || e.status === "RESULTS_PUBLISHED").length ?? 0;
    const pendingPublication = exams?.filter((e) => e.status === "COMPLETED").length ?? 0;

    // Fetch total published results count
    const { count: totalResults } = await supabase
      .from("result")
      .select("*", { count: "exact", head: true });

    // Fetch pending marks submissions
    const { count: pendingSubmissions } = await supabase
      .from("marks_submission")
      .select("*", { count: "exact", head: true })
      .in("status", ["SUBMITTED", "UNDER_REVIEW"]);

    // Fetch total exam schedules count
    const { count: totalSchedules } = await supabase
      .from("exam_schedule")
      .select("*", { count: "exact", head: true });

    res.json({
      totalExams,
      upcomingExams,
      ongoingExams,
      completedExams,
      pendingPublication,
      totalResults: totalResults ?? 0,
      pendingSubmissions: pendingSubmissions ?? 0,
      totalSchedules: totalSchedules ?? 0,
      recentExams: exams?.slice(0, 5) ?? [],
    });
  }),
);

// =====================================================================
// 2. MASTER DATA OPTIONS (SEMESTERS, OFFERINGS, GRADES)
// =====================================================================
examsRouter.get(
  "/master/options",
  requireRole("ADMIN", "FACULTY"),
  asyncHandler(async (_req, res) => {
    const supabase = getDb();

    const [semsRes, offeringsRes, gradesRes] = await Promise.all([
      supabase.from("semester").select("semester_id, term, is_active, academic_year(label)").order("semester_id", { ascending: false }),
      supabase.from("course_offering").select("offering_id, course_code, semester_id, division_id, employee_id, course(course_title, credits, dept_code, course_type), employee(full_name, dept_code)"),
      supabase.from("grade_scale").select("grade, min_pct, grade_point, is_pass, description").order("grade_point", { ascending: false }),
    ]);

    if (semsRes.error) throw new HttpError(500, semsRes.error.message);
    if (offeringsRes.error) throw new HttpError(500, offeringsRes.error.message);
    if (gradesRes.error) throw new HttpError(500, gradesRes.error.message);

    res.json({
      semesters: semsRes.data,
      offerings: offeringsRes.data,
      grades: gradesRes.data,
    });
  }),
);

// =====================================================================
// 3. CHRONOLOGICAL TIMETABLE (STUDENT FILTERED / CAMPUS-WIDE)
// =====================================================================
examsRouter.get(
  "/timetable/all",
  requireRole("ADMIN", "FACULTY", "STUDENT"),
  asyncHandler(async (req, res) => {
    const supabase = getDb();
    const user = req.user;
    const isStudent = user?.roles.includes("STUDENT");

    let query = supabase
      .from("exam_schedule")
      .select("schedule_id, exam_id, offering_id, exam_date, start_time, end_time, max_marks, passing_marks, exam(exam_name, exam_type, status, sem_no, semester_id), course_offering(*, course(*), employee(*))")
      .order("exam_date", { ascending: true })
      .order("start_time", { ascending: true });

    // If student, strictly filter to their enrolled courses / semester
    if (isStudent) {
      const studentId = user?.studentId;
      if (!studentId) {
        throw new HttpError(403, "Student identity not associated with user account");
      }

      const { data: enrollments } = await supabase
        .from("course_enrollment")
        .select("offering_id")
        .eq("student_id", studentId);

      const enrolledOfferingIds = enrollments?.map((e) => e.offering_id) ?? [];
      if (enrolledOfferingIds.length === 0) {
        return res.json({ items: [], message: "No enrolled courses found for student." });
      }

      query = query.in("offering_id", enrolledOfferingIds);
    }

    const { data: schedules, error } = await query;
    if (error) throw new HttpError(500, error.message);

    res.json({ items: schedules ?? [] });
  }),
);

// =====================================================================
// 4. STUDENT RESULT PORTAL (AUTHENTICATED STUDENT ONLY)
// =====================================================================
examsRouter.get(
  "/student/results",
  requireRole("STUDENT"),
  asyncHandler(async (req, res) => {
    const supabase = getDb();
    const user = req.user;
    const studentId = user?.studentId;

    if (!studentId) {
      throw new HttpError(403, "Student identity not associated with user account");
    }

    // Fetch student profile
    const { data: student, error: studErr } = await supabase
      .from("student")
      .select("student_id, enrollment_no, full_name, email, admission_year, program(*)")
      .eq("student_id", studentId)
      .single();

    if (studErr) throw new HttpError(500, studErr.message);

    // Compute cumulative GPA via RPC
    const { data: cgpa } = await supabase.rpc("fn_calculate_cgpa", { p_student_id: studentId });

    // Fetch all published results for this student
    const { data: results, error: resErr } = await supabase
      .from("result")
      .select("result_id, student_id, offering_id, total_marks, max_marks, percentage, grade, published_on, course_offering(*, course(*), semester(*, academic_year(*)))")
      .eq("student_id", studentId)
      .order("published_on", { ascending: false });

    if (resErr) throw new HttpError(500, resErr.message);

    // Group results by semester
    const semMap = new Map<number, { semesterId: number; term: string; academicYear: string; sgpa: number | null; courses: unknown[] }>();

    for (const r of (results as any[]) ?? []) {
      const offering = Array.isArray(r.course_offering) ? r.course_offering[0] : r.course_offering;
      const sem = Array.isArray(offering?.semester) ? offering?.semester[0] : offering?.semester;
      const course = Array.isArray(offering?.course) ? offering?.course[0] : offering?.course;
      const ay = Array.isArray(sem?.academic_year) ? sem?.academic_year[0] : sem?.academic_year;
      if (!sem) continue;

      const semId = sem.semester_id;
      if (!semMap.has(semId)) {
        semMap.set(semId, {
          semesterId: semId,
          term: sem.term,
          academicYear: ay?.label ?? "",
          sgpa: null,
          courses: [],
        });
      }

      semMap.get(semId)!.courses.push({
        resultId: r.result_id,
        courseCode: offering?.course_code,
        courseTitle: course?.course_title,
        courseType: course?.course_type,
        credits: course?.credits,
        totalMarks: r.total_marks,
        maxMarks: r.max_marks,
        percentage: r.percentage,
        grade: r.grade,
        publishedOn: r.published_on,
      });
    }

    // Compute SGPA for each semester
    for (const [semId, semData] of semMap.entries()) {
      const { data: sgpaVal } = await supabase.rpc("fn_calculate_sgpa", { p_student_id: studentId, p_semester_id: semId });
      semData.sgpa = sgpaVal ?? null;
    }

    res.json({
      student,
      cgpa: cgpa ?? null,
      semesters: Array.from(semMap.values()),
    });
  }),
);

// Hall ticket for student
examsRouter.get(
  "/student/hall-ticket/:examId",
  requireRole("STUDENT"),
  asyncHandler(async (req, res) => {
    const { examId } = req.params;
    const supabase = getDb();
    const studentId = req.user?.studentId;

    if (!studentId) throw new HttpError(403, "Student identity not associated with user account");

    const { data: hallTicket, error } = await supabase
      .from("hall_ticket")
      .select("*, exam(*)")
      .eq("exam_id", examId)
      .eq("student_id", studentId)
      .maybeSingle();

    if (error) throw new HttpError(500, error.message);
    if (!hallTicket) throw new HttpError(404, "Hall ticket has not yet been generated for this examination");

    res.json(hallTicket);
  }),
);

// List all pending marks submissions across campus
examsRouter.get(
  "/submissions/pending",
  requireRole("ADMIN"),
  asyncHandler(async (_req, res) => {
    const supabase = getDb();

    const { data, error } = await supabase
      .from("marks_submission")
      .select("*, exam(exam_name, exam_type), course_offering(*, course(*), employee(*))")
      .order("updated_at", { ascending: false });

    if (error) throw new HttpError(500, error.message);
    res.json({ items: data ?? [] });
  }),
);

// =====================================================================
// 5. EXAMS LIST & SEARCH
// =====================================================================
examsRouter.get(
  "/",
  requireRole("ADMIN", "FACULTY", "STUDENT"),
  asyncHandler(async (req, res) => {
    const supabase = getDb();
    const { status, type, semNo, search } = req.query;

    let query = supabase
      .from("exam")
      .select("*, semester(term, academic_year(label))")
      .order("start_date", { ascending: false });

    if (status && typeof status === "string") {
      query = query.eq("status", status);
    }
    if (type && typeof type === "string") {
      query = query.eq("exam_type", type);
    }
    if (semNo) {
      query = query.eq("sem_no", Number(semNo));
    }

    const { data: exams, error } = await query;
    if (error) throw new HttpError(500, error.message);

    let filtered = exams ?? [];
    if (search && typeof search === "string") {
      const q = search.toLowerCase();
      filtered = filtered.filter(
        (e) =>
          e.exam_name.toLowerCase().includes(q) ||
          e.exam_id.toLowerCase().includes(q) ||
          e.exam_type.toLowerCase().includes(q),
      );
    }

    res.json({
      module: "exams",
      group: "G2",
      title: "Examination and Results Management",
      items: filtered,
    });
  }),
);

// =====================================================================
// 6. CREATE EXAMINATION (ADMIN ONLY)
// =====================================================================
const createExamSchema = z.object({
  examId: z.string().regex(/^EX-[0-9]{4}-S[0-9]-[0-9]{2}$/, "Invalid Exam ID format. Must match EX-YYYY-SX-NN (e.g., EX-2026-S5-02)"),
  examName: z.string().min(3).max(100),
  examType: z.enum(["ISE", "MSE", "ESE", "PRACTICAL", "ORAL"]),
  semesterId: z.number().int().positive(),
  semNo: z.number().int().min(1).max(8),
  registrationDeadline: z.string().optional().nullable(),
  startDate: z.string(),
  endDate: z.string(),
  status: z.enum(["SCHEDULED", "REGISTRATION_OPEN", "ONGOING", "COMPLETED", "RESULTS_PUBLISHED"]).default("SCHEDULED"),
});

examsRouter.post(
  "/",
  requireRole("ADMIN"),
  asyncHandler(async (req, res) => {
    const parsed = createExamSchema.parse(req.body);

    if (new Date(parsed.endDate) < new Date(parsed.startDate)) {
      throw new HttpError(400, "End date cannot be earlier than start date");
    }

    const supabase = getDb();

    // Check if exam_id already exists
    const { data: existing } = await supabase.from("exam").select("exam_id").eq("exam_id", parsed.examId).maybeSingle();
    if (existing) {
      throw new HttpError(409, `Examination ID '${parsed.examId}' already exists`);
    }

    const { data, error } = await supabase
      .from("exam")
      .insert({
        exam_id: parsed.examId,
        exam_name: parsed.examName,
        exam_type: parsed.examType,
        semester_id: parsed.semesterId,
        sem_no: parsed.semNo,
        registration_deadline: parsed.registrationDeadline || null,
        start_date: parsed.startDate,
        end_date: parsed.endDate,
        status: parsed.status,
      })
      .select("*, semester(term, academic_year(label))")
      .single();

    if (error) throw new HttpError(400, error.message);
    res.status(201).json(data);
  }),
);

// =====================================================================
// 7. GET SINGLE EXAM DETAILS WITH SCHEDULES
// =====================================================================
examsRouter.get(
  "/:examId",
  requireRole("ADMIN", "FACULTY", "STUDENT"),
  asyncHandler(async (req, res) => {
    const { examId } = req.params;
    const supabase = getDb();

    const { data: exam, error } = await supabase
      .from("exam")
      .select("*, semester(term, academic_year(label))")
      .eq("exam_id", examId)
      .maybeSingle();

    if (error) throw new HttpError(500, error.message);
    if (!exam) throw new HttpError(404, `Exam '${examId}' not found`);

    const { data: schedules } = await supabase
      .from("exam_schedule")
      .select("*, course_offering(*, course(*), employee(*))")
      .eq("exam_id", examId)
      .order("exam_date", { ascending: true })
      .order("start_time", { ascending: true });

    res.json({ exam, schedules: schedules ?? [] });
  }),
);

// =====================================================================
// 8. UPDATE EXAM (ADMIN ONLY)
// =====================================================================
const updateExamSchema = z.object({
  examName: z.string().min(3).max(100).optional(),
  examType: z.enum(["ISE", "MSE", "ESE", "PRACTICAL", "ORAL"]).optional(),
  semesterId: z.number().int().positive().optional(),
  semNo: z.number().int().min(1).max(8).optional(),
  registrationDeadline: z.string().optional().nullable(),
  startDate: z.string().optional(),
  endDate: z.string().optional(),
  status: z.enum(["SCHEDULED", "REGISTRATION_OPEN", "ONGOING", "COMPLETED", "RESULTS_PUBLISHED"]).optional(),
});

examsRouter.put(
  "/:examId",
  requireRole("ADMIN"),
  asyncHandler(async (req, res) => {
    const { examId } = req.params;
    const parsed = updateExamSchema.parse(req.body);
    const supabase = getDb();

    if (parsed.startDate && parsed.endDate && new Date(parsed.endDate) < new Date(parsed.startDate)) {
      throw new HttpError(400, "End date cannot be earlier than start date");
    }

    const payload: Record<string, unknown> = { updated_at: new Date().toISOString() };
    if (parsed.examName) payload.exam_name = parsed.examName;
    if (parsed.examType) payload.exam_type = parsed.examType;
    if (parsed.semesterId) payload.semester_id = parsed.semesterId;
    if (parsed.semNo) payload.sem_no = parsed.semNo;
    if (parsed.registrationDeadline !== undefined) payload.registration_deadline = parsed.registrationDeadline;
    if (parsed.startDate) payload.start_date = parsed.startDate;
    if (parsed.endDate) payload.end_date = parsed.endDate;
    if (parsed.status) payload.status = parsed.status;

    const { data, error } = await supabase
      .from("exam")
      .update(payload)
      .eq("exam_id", examId)
      .select("*, semester(term, academic_year(label))")
      .single();

    if (error) throw new HttpError(400, error.message);
    res.json(data);
  }),
);

// =====================================================================
// 9. DELETE EXAM (ADMIN ONLY)
// =====================================================================
examsRouter.delete(
  "/:examId",
  requireRole("ADMIN"),
  asyncHandler(async (req, res) => {
    const { examId } = req.params;
    const supabase = getDb();

    // Check if published results or marks exist
    const { count: marksCount } = await supabase
      .from("marks")
      .select("*", { count: "exact", head: true })
      .eq("exam_id", examId);

    if (marksCount && marksCount > 0) {
      throw new HttpError(400, "Cannot delete examination with submitted student marks. Remove marks or cancel exam instead.");
    }

    // Delete schedules first
    await supabase.from("exam_schedule").delete().eq("exam_id", examId);

    const { error } = await supabase.from("exam").delete().eq("exam_id", examId);
    if (error) throw new HttpError(400, error.message);

    res.json({ message: `Exam '${examId}' deleted successfully.` });
  }),
);

// =====================================================================
// 10. EXAM SCHEDULES (CRUD & TIMETABLE CONFLICT DETECTION)
// =====================================================================
const scheduleSchema = z.object({
  offeringId: z.number().int().positive(),
  examDate: z.string(),
  startTime: z.string().regex(/^([01]\d|2[0-3]):([0-5]\d)(:[0-5]\d)?$/, "Invalid start time format (HH:MM)"),
  endTime: z.string().regex(/^([01]\d|2[0-3]):([0-5]\d)(:[0-5]\d)?$/, "Invalid end time format (HH:MM)"),
  maxMarks: z.number().int().min(1).max(200),
  passingMarks: z.number().int().min(1).max(200),
});

examsRouter.get(
  "/:examId/schedules",
  requireRole("ADMIN", "FACULTY", "STUDENT"),
  asyncHandler(async (req, res) => {
    const { examId } = req.params;
    const supabase = getDb();

    const { data, error } = await supabase
      .from("exam_schedule")
      .select("*, course_offering(*, course(*), employee(*))")
      .eq("exam_id", examId)
      .order("exam_date", { ascending: true })
      .order("start_time", { ascending: true });

    if (error) throw new HttpError(500, error.message);
    res.json(data);
  }),
);

examsRouter.post(
  "/:examId/schedules",
  requireRole("ADMIN"),
  asyncHandler(async (req, res) => {
    const { examId } = req.params;
    const parsed = scheduleSchema.parse(req.body);

    if (parsed.passingMarks > parsed.maxMarks) {
      throw new HttpError(400, "Passing marks cannot exceed maximum marks");
    }

    const fmtTime = (t: string) => (t.length === 5 ? `${t}:00` : t);
    const sTime = fmtTime(parsed.startTime);
    const eTime = fmtTime(parsed.endTime);

    if (eTime <= sTime) {
      throw new HttpError(400, "End time must be after start time");
    }

    const supabase = getDb();

    // Verify exam existence
    const { data: exam } = await supabase.from("exam").select("*").eq("exam_id", examId).single();
    if (!exam) throw new HttpError(404, "Exam not found");

    // Verify offering belongs to exam semester
    const { data: offering } = await supabase
      .from("course_offering")
      .select("*, course(*), employee(*)")
      .eq("offering_id", parsed.offeringId)
      .single();

    if (!offering) throw new HttpError(404, "Course offering not found");
    if (offering.semester_id !== exam.semester_id) {
      throw new HttpError(400, `Offering belongs to semester ${offering.semester_id}, but exam is for semester ${exam.semester_id}`);
    }

    // --- TIMETABLE CONFLICT DETECTION ---
    // 1. Check if same offering is already scheduled in this exam
    const { data: existingSameOffering } = await supabase
      .from("exam_schedule")
      .select("schedule_id")
      .eq("exam_id", examId)
      .eq("offering_id", parsed.offeringId)
      .maybeSingle();

    // 2. Check if the faculty member teaching this offering is already scheduled for another paper at an overlapping time on the same date
    if (offering.employee_id) {
      const { data: facultySchedules } = await supabase
        .from("exam_schedule")
        .select("schedule_id, exam_date, start_time, end_time, course_offering!inner(employee_id, course_code)")
        .eq("exam_date", parsed.examDate)
        .eq("course_offering.employee_id", offering.employee_id);

      const facultyConflict = facultySchedules?.find((s) => {
        if (existingSameOffering && s.schedule_id === existingSameOffering.schedule_id) return false;
        return s.start_time < eTime && s.end_time > sTime;
      });

      if (facultyConflict) {
        const fOff: any = Array.isArray(facultyConflict.course_offering) ? facultyConflict.course_offering[0] : facultyConflict.course_offering;
        throw new HttpError(
          409,
          `Timetable conflict: Faculty ${offering.employee?.full_name ?? offering.employee_id} is already scheduled for paper ${fOff?.course_code} on ${parsed.examDate} between ${facultyConflict.start_time} and ${facultyConflict.end_time}`,
        );
      }
    }

    // 3. Check for student division overlap on the same date/time in the same exam
    if (offering.division_id) {
      const { data: divisionSchedules } = await supabase
        .from("exam_schedule")
        .select("schedule_id, exam_date, start_time, end_time, course_offering!inner(division_id, course_code)")
        .eq("exam_id", examId)
        .eq("exam_date", parsed.examDate)
        .eq("course_offering.division_id", offering.division_id);

      const divConflict = divisionSchedules?.find((s) => {
        if (existingSameOffering && s.schedule_id === existingSameOffering.schedule_id) return false;
        return s.start_time < eTime && s.end_time > sTime;
      });

      if (divConflict) {
        const dOff: any = Array.isArray(divConflict.course_offering) ? divConflict.course_offering[0] : divConflict.course_offering;
        throw new HttpError(
          409,
          `Timetable conflict: Students in this division already have exam for ${dOff?.course_code} on ${parsed.examDate} from ${divConflict.start_time} to ${divConflict.end_time}`,
        );
      }
    }

    // Upsert schedule
    let result;
    if (existingSameOffering) {
      const { data, error } = await supabase
        .from("exam_schedule")
        .update({
          exam_date: parsed.examDate,
          start_time: sTime,
          end_time: eTime,
          max_marks: parsed.maxMarks,
          passing_marks: parsed.passingMarks,
          updated_at: new Date().toISOString(),
        })
        .eq("schedule_id", existingSameOffering.schedule_id)
        .select("*, course_offering(*, course(*), employee(*))")
        .single();
      if (error) throw new HttpError(400, error.message);
      result = data;
    } else {
      const { data, error } = await supabase
        .from("exam_schedule")
        .insert({
          exam_id: examId,
          offering_id: parsed.offeringId,
          exam_date: parsed.examDate,
          start_time: sTime,
          end_time: eTime,
          max_marks: parsed.maxMarks,
          passing_marks: parsed.passingMarks,
        })
        .select("*, course_offering(*, course(*), employee(*))")
        .single();
      if (error) throw new HttpError(400, error.message);
      result = data;
    }

    res.status(201).json(result);
  }),
);

examsRouter.delete(
  "/:examId/schedules/:scheduleId",
  requireRole("ADMIN"),
  asyncHandler(async (req, res) => {
    const { examId, scheduleId } = req.params;
    const supabase = getDb();

    const { data: sch } = await supabase
      .from("exam_schedule")
      .select("offering_id")
      .eq("schedule_id", scheduleId)
      .eq("exam_id", examId)
      .single();

    if (!sch) throw new HttpError(404, "Schedule not found");

    // Check if marks exist for this schedule
    const { count: marksCount } = await supabase
      .from("marks")
      .select("*", { count: "exact", head: true })
      .eq("exam_id", examId)
      .eq("offering_id", sch.offering_id);

    if (marksCount && marksCount > 0) {
      throw new HttpError(400, "Cannot delete schedule because marks have already been recorded for this paper.");
    }

    await supabase.from("exam_registration").delete().eq("exam_id", examId).eq("offering_id", sch.offering_id);
    const { error } = await supabase.from("exam_schedule").delete().eq("schedule_id", scheduleId);
    if (error) throw new HttpError(400, error.message);

    res.json({ message: "Schedule deleted successfully." });
  }),
);

// =====================================================================
// 11. MARKS ENTRY - OFFERINGS LIST FOR FACULTY / ADMIN
// =====================================================================
examsRouter.get(
  "/:examId/offerings",
  requireRole("ADMIN", "FACULTY"),
  asyncHandler(async (req, res) => {
    const { examId } = req.params;
    const supabase = getDb();
    const user = req.user;
    const isOnlyFaculty = user?.roles.includes("FACULTY") && !user?.roles.includes("ADMIN");

    // Fetch schedules for this exam
    let schQuery = supabase
      .from("exam_schedule")
      .select("*, course_offering(*, course(*), employee(*))")
      .eq("exam_id", examId);

    const { data: schedules, error: schErr } = await schQuery;
    if (schErr) throw new HttpError(500, schErr.message);

    // Fetch all submissions for this exam
    const { data: submissions } = await supabase
      .from("marks_submission")
      .select("*")
      .eq("exam_id", examId);

    const subMap = new Map((submissions ?? []).map((s) => [s.offering_id, s]));

    // Fetch counts of entered marks per offering
    const { data: marksCounts } = await supabase
      .from("marks")
      .select("offering_id")
      .eq("exam_id", examId);

    const marksCountMap = new Map<number, number>();
    for (const m of marksCounts ?? []) {
      marksCountMap.set(m.offering_id, (marksCountMap.get(m.offering_id) ?? 0) + 1);
    }

    let items = (schedules ?? []).map((s) => {
      const submission = subMap.get(s.offering_id);
      return {
        scheduleId: s.schedule_id,
        examId: s.exam_id,
        offeringId: s.offering_id,
        courseCode: s.course_offering?.course_code,
        courseTitle: s.course_offering?.course?.course_title,
        credits: s.course_offering?.course?.credits,
        facultyId: s.course_offering?.employee_id,
        facultyName: s.course_offering?.employee?.full_name,
        examDate: s.exam_date,
        maxMarks: s.max_marks,
        passingMarks: s.passingMarks ?? s.passing_marks,
        marksEnteredCount: marksCountMap.get(s.offering_id) ?? 0,
        submissionStatus: submission?.status ?? "DRAFT",
        submittedAt: submission?.submitted_at,
        reviewedAt: submission?.reviewed_at,
        rejectionReason: submission?.rejection_reason || submission?.remarks,
      };
    });

    if (isOnlyFaculty && user?.employeeId) {
      items = items.filter((item) => item.facultyId === user.employeeId);
    }

    res.json({ items });
  }),
);

// =====================================================================
// 12. MARKS ENTRY - STUDENT MARKSHEET (FETCH & SAVE/SUBMIT)
// =====================================================================
examsRouter.get(
  "/:examId/offerings/:offeringId/marks",
  requireRole("ADMIN", "FACULTY"),
  asyncHandler(async (req, res) => {
    const { examId, offeringId } = req.params;
    const offId = Number(offeringId);
    const supabase = getDb();
    const user = req.user;

    // Verify offering and schedule
    const { data: schedule } = await supabase
      .from("exam_schedule")
      .select("*, course_offering(*, course(*), employee(*))")
      .eq("exam_id", examId)
      .eq("offering_id", offId)
      .single();

    if (!schedule) throw new HttpError(404, "Examination schedule not found for this course paper");

    // If faculty, verify they teach this course
    const isOnlyFaculty = user?.roles.includes("FACULTY") && !user?.roles.includes("ADMIN");
    if (isOnlyFaculty && schedule.course_offering?.employee_id !== user?.employeeId) {
      throw new HttpError(403, "You are not assigned as the instructor for this course offering");
    }

    // Fetch enrolled students for this course offering
    const { data: enrollments, error: enrErr } = await supabase
      .from("course_enrollment")
      .select("student_id, student(full_name, enrollment_no, email)")
      .eq("offering_id", offId)
      .eq("status", "ENROLLED")
      .order("student_id", { ascending: true });

    if (enrErr) throw new HttpError(500, enrErr.message);

    // Fetch existing marks
    const { data: existingMarks } = await supabase
      .from("marks")
      .select("*")
      .eq("exam_id", examId)
      .eq("offering_id", offId);

    const marksMap = new Map((existingMarks ?? []).map((m) => [m.student_id, m]));

    // Fetch submission status
    const { data: submission } = await supabase
      .from("marks_submission")
      .select("*")
      .eq("exam_id", examId)
      .eq("offering_id", offId)
      .maybeSingle();

    const students = (enrollments ?? []).map((e) => {
      const m = marksMap.get(e.student_id);
      return {
        studentId: e.student_id,
        enrollmentNo: (e.student as { enrollment_no?: string })?.enrollment_no ?? e.student_id,
        fullName: (e.student as { full_name?: string })?.full_name ?? "Student",
        marksObtained: m ? m.marks_obtained : null,
        isAbsent: m ? Boolean(m.is_absent) : false,
      };
    });

    res.json({
      examId,
      offeringId: offId,
      schedule,
      submission: submission ?? { status: "DRAFT" },
      students,
    });
  }),
);

const saveMarksSchema = z.object({
  action: z.enum(["SAVE_DRAFT", "SUBMIT"]),
  marks: z.array(
    z.object({
      studentId: z.string(),
      marksObtained: z.number().nullable(),
      isAbsent: z.boolean().default(false),
    }),
  ),
});

examsRouter.post(
  "/:examId/offerings/:offeringId/marks",
  requireRole("ADMIN", "FACULTY"),
  asyncHandler(async (req, res) => {
    const { examId, offeringId } = req.params;
    const offId = Number(offeringId);
    const parsed = saveMarksSchema.parse(req.body);
    const supabase = getDb();
    const user = req.user;

    const { data: schedule } = await supabase
      .from("exam_schedule")
      .select("*, course_offering(*)")
      .eq("exam_id", examId)
      .eq("offering_id", offId)
      .single();

    if (!schedule) throw new HttpError(404, "Exam schedule not found");

    const isOnlyFaculty = user?.roles.includes("FACULTY") && !user?.roles.includes("ADMIN");
    if (isOnlyFaculty && schedule.course_offering?.employee_id !== user?.employeeId) {
      throw new HttpError(403, "You are not authorized to enter marks for this offering");
    }

    // Check submission status: cannot edit if already SUBMITTED or APPROVED (unless ADMIN)
    const { data: submission } = await supabase
      .from("marks_submission")
      .select("*")
      .eq("exam_id", examId)
      .eq("offering_id", offId)
      .maybeSingle();

    if (submission && submission.status === "APPROVED") {
      throw new HttpError(400, "Marks have already been approved by administration and are locked.");
    }

    if (isOnlyFaculty && submission && (submission.status === "SUBMITTED" || submission.status === "UNDER_REVIEW")) {
      throw new HttpError(400, "Marks have been submitted for review. Contact the examination cell to make corrections.");
    }

    // Validate ranges
    for (const m of parsed.marks) {
      if (m.isAbsent) {
        if (m.marksObtained !== null && m.marksObtained !== undefined) {
          throw new HttpError(400, `Student ${m.studentId} is marked absent, marks must be empty`);
        }
      } else if (m.marksObtained !== null && m.marksObtained !== undefined) {
        if (m.marksObtained < 0 || m.marksObtained > schedule.max_marks) {
          throw new HttpError(400, `Marks for student ${m.studentId} must be between 0 and maximum marks (${schedule.max_marks})`);
        }
      }
    }

    // Auto-register any enrolled students in exam_registration if not yet present
    for (const m of parsed.marks) {
      const { data: reg } = await supabase
        .from("exam_registration")
        .select("registration_id")
        .eq("exam_id", examId)
        .eq("student_id", m.studentId)
        .eq("offering_id", offId)
        .maybeSingle();

      if (!reg) {
        await supabase.from("exam_registration").insert({
          exam_id: examId,
          student_id: m.studentId,
          offering_id: offId,
          status: "REGISTERED",
        });
      }
    }

    // Upsert marks
    const employeeId = user?.employeeId ?? schedule.course_offering?.employee_id ?? null;

    for (const m of parsed.marks) {
      if (m.marksObtained === null && !m.isAbsent) continue;

      const marksVal = m.isAbsent ? null : m.marksObtained;
      const isAbsentVal = m.isAbsent ? 1 : 0;

      const { data: existing } = await supabase
        .from("marks")
        .select("marks_id")
        .eq("exam_id", examId)
        .eq("student_id", m.studentId)
        .eq("offering_id", offId)
        .maybeSingle();

      if (existing) {
        await supabase
          .from("marks")
          .update({
            marks_obtained: marksVal,
            is_absent: isAbsentVal,
            entered_by: employeeId,
            updated_at: new Date().toISOString(),
          })
          .eq("marks_id", existing.marks_id);
      } else {
        await supabase.from("marks").insert({
          exam_id: examId,
          student_id: m.studentId,
          offering_id: offId,
          marks_obtained: marksVal,
          is_absent: isAbsentVal,
          entered_by: employeeId,
        });
      }
    }

    // Update marks_submission status
    const newStatus = parsed.action === "SUBMIT" ? "SUBMITTED" : "DRAFT";
    const subPayload: Record<string, unknown> = {
      exam_id: examId,
      offering_id: offId,
      status: newStatus,
      submitted_by: employeeId,
      updated_at: new Date().toISOString(),
    };
    if (parsed.action === "SUBMIT") {
      subPayload.submitted_at = new Date().toISOString();
      subPayload.rejection_reason = null;
      subPayload.remarks = null;
    }

    if (submission) {
      const { error: updErr } = await supabase
        .from("marks_submission")
        .update(subPayload)
        .eq("submission_id", submission.submission_id);
      if (updErr) throw new HttpError(400, updErr.message);
    } else {
      const { error: insErr } = await supabase.from("marks_submission").insert(subPayload);
      if (insErr) throw new HttpError(400, insErr.message);
    }

    res.json({
      message: parsed.action === "SUBMIT" ? "Marks submitted successfully for administrative review." : "Marks draft saved successfully.",
      status: newStatus,
    });
  }),
);

// =====================================================================
// 13. MARKS VERIFICATION & APPROVAL (ADMIN ONLY)
// =====================================================================
const reviewSchema = z.object({
  action: z.enum(["UNDER_REVIEW", "APPROVE", "REJECT"]),
  rejectionReason: z.string().optional(),
});

examsRouter.post(
  "/:examId/offerings/:offeringId/review",
  requireRole("ADMIN"),
  asyncHandler(async (req, res) => {
    const { examId, offeringId } = req.params;
    const offId = Number(offeringId);
    const parsed = reviewSchema.parse(req.body);
    const supabase = getDb();
    const user = req.user;

    const { data: sub } = await supabase
      .from("marks_submission")
      .select("*")
      .eq("exam_id", examId)
      .eq("offering_id", offId)
      .maybeSingle();

    if (!sub) throw new HttpError(404, "No marks submission found for this offering");

    if (parsed.action === "REJECT" && !parsed.rejectionReason) {
      throw new HttpError(400, "A rejection reason is required when returning marks for correction");
    }

    const nextStatus = parsed.action === "APPROVE" ? "APPROVED" : parsed.action === "REJECT" ? "REJECTED" : "UNDER_REVIEW";

    const { error } = await supabase
      .from("marks_submission")
      .update({
        status: nextStatus,
        reviewed_by: user?.id,
        reviewed_at: new Date().toISOString(),
        rejection_reason: parsed.action === "REJECT" ? parsed.rejectionReason : null,
        remarks: parsed.action === "REJECT" ? parsed.rejectionReason : null,
        updated_at: new Date().toISOString(),
      })
      .eq("submission_id", sub.submission_id);

    if (error) throw new HttpError(500, error.message);

    res.json({
      message: `Marks submission status updated to ${nextStatus}`,
      status: nextStatus,
    });
  }),
);

// =====================================================================
// 14. RESULT PREVIEW, CALCULATION & PUBLICATION (ADMIN ONLY)
// =====================================================================
examsRouter.get(
  "/:examId/results/preview",
  requireRole("ADMIN"),
  asyncHandler(async (req, res) => {
    const { examId } = req.params;
    const supabase = getDb();

    const { data: exam } = await supabase.from("exam").select("*").eq("exam_id", examId).single();
    if (!exam) throw new HttpError(404, "Exam not found");

    // Fetch schedules
    const { data: schedules } = await supabase
      .from("exam_schedule")
      .select("*, course_offering(*, course(*))")
      .eq("exam_id", examId);

    // Fetch marks entered for this exam
    const { data: marks } = await supabase
      .from("marks")
      .select("*, student(full_name, enrollment_no)")
      .eq("exam_id", examId);

    // Fetch grade scale
    const { data: grades } = await supabase
      .from("grade_scale")
      .select("*")
      .order("min_pct", { ascending: false });

    // Fetch submission statuses
    const { data: submissions } = await supabase
      .from("marks_submission")
      .select("*")
      .eq("exam_id", examId);

    const subMap = new Map((submissions ?? []).map((s) => [s.offering_id, s.status]));

    // Group marks by student and offering
    const studentResultsMap = new Map<string, { studentId: string; fullName: string; totalMarks: number; maxMarks: number; courses: unknown[] }>();

    const schMap = new Map((schedules ?? []).map((s) => [s.offering_id, s]));

    for (const m of marks ?? []) {
      const sch = schMap.get(m.offering_id);
      if (!sch) continue;

      const sid = m.student_id;
      if (!studentResultsMap.has(sid)) {
        studentResultsMap.set(sid, {
          studentId: sid,
          fullName: (m.student as { full_name?: string })?.full_name ?? sid,
          totalMarks: 0,
          maxMarks: 0,
          courses: [],
        });
      }

      const item = studentResultsMap.get(sid)!;
      const obtained = m.marks_obtained ?? 0;
      item.totalMarks += obtained;
      item.maxMarks += sch.max_marks;

      const pct = sch.max_marks > 0 ? (obtained * 100) / sch.max_marks : 0;
      const grade = grades?.find((g) => pct >= g.min_pct) ?? { grade: "F", grade_point: 0, is_pass: 0 };

      item.courses.push({
        offeringId: m.offering_id,
        courseCode: sch.course_offering?.course_code,
        courseTitle: sch.course_offering?.course?.course_title,
        credits: sch.course_offering?.course?.credits,
        obtained,
        maxMarks: sch.max_marks,
        percentage: Number(pct.toFixed(2)),
        grade: grade.grade,
        isAbsent: Boolean(m.is_absent),
      });
    }

    const previewList = Array.from(studentResultsMap.values()).map((sr) => {
      const pct = sr.maxMarks > 0 ? Number(((sr.totalMarks * 100) / sr.maxMarks).toFixed(2)) : 0;
      const matchedGrade = grades?.find((g) => pct >= g.min_pct) ?? { grade: "F", grade_point: 0, is_pass: 0 };
      return {
        ...sr,
        percentage: pct,
        grade: matchedGrade.grade,
        status: matchedGrade.is_pass === 1 ? "PASS" : "FAIL",
      };
    });

    const passedCount = previewList.filter((p) => p.status === "PASS").length;
    const failedCount = previewList.filter((p) => p.status === "FAIL").length;

    const unapprovedOfferings = (schedules ?? []).filter((s) => subMap.get(s.offering_id) !== "APPROVED");

    res.json({
      exam,
      totalStudents: previewList.length,
      passedCount,
      failedCount,
      totalSchedules: schedules?.length ?? 0,
      approvedSchedules: (schedules?.length ?? 0) - unapprovedOfferings.length,
      unapprovedOfferings: unapprovedOfferings.map((u) => ({ offeringId: u.offering_id, courseCode: u.course_offering?.course_code })),
      readyToPublish: unapprovedOfferings.length === 0 && previewList.length > 0,
      preview: previewList.slice(0, 50),
    });
  }),
);

examsRouter.post(
  "/:examId/results/publish",
  requireRole("ADMIN"),
  asyncHandler(async (req, res) => {
    const { examId } = req.params;
    const supabase = getDb();

    // Call stored procedure sp_publish_results
    const { data, error } = await supabase.rpc("sp_publish_results", { p_exam_id: examId });

    if (error) {
      throw new HttpError(400, `Result publication failed: ${error.message}`);
    }

    // Ensure status is updated
    await supabase.from("exam").update({ status: "RESULTS_PUBLISHED", updated_at: new Date().toISOString() }).eq("exam_id", examId);

    res.json({
      message: "Results published successfully.",
      summary: data,
    });
  }),
);

// Get published results for an exam
examsRouter.get(
  "/:examId/results",
  requireRole("ADMIN", "FACULTY"),
  asyncHandler(async (req, res) => {
    const { examId } = req.params;
    const supabase = getDb();

    const { data: exam } = await supabase.from("exam").select("*, semester(term, academic_year(label))").eq("exam_id", examId).single();
    if (!exam) throw new HttpError(404, "Exam not found");

    const { data: results, error } = await supabase
      .from("result")
      .select("*, student(full_name, enrollment_no), course_offering(*, course(*))")
      .in(
        "offering_id",
        (await supabase.from("exam_schedule").select("offering_id").eq("exam_id", examId)).data?.map((s) => s.offering_id) ?? [],
      )
      .order("student_id", { ascending: true });

    if (error) throw new HttpError(500, error.message);

    res.json({ exam, results: results ?? [] });
  }),
);
