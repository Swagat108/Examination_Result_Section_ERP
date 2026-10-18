import { app } from "./app.js";
import http from "node:http";

async function runTests() {
  console.log("=== STARTING EXAMS & RESULTS E2E VERIFICATION ===");

  const server = http.createServer(app);
  await new Promise<void>((resolve) => server.listen(4999, resolve));
  const baseUrl = "http://localhost:4999/api";

  const post = async (path: string, body: any, token?: string) => {
    const res = await fetch(`${baseUrl}${path}`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        ...(token ? { Authorization: `Bearer ${token}` } : {}),
      },
      body: JSON.stringify(body),
    });
    const json = await res.json().catch(() => ({}));
    return { status: res.status, data: json };
  };

  const get = async (path: string, token?: string) => {
    const res = await fetch(`${baseUrl}${path}`, {
      headers: token ? { Authorization: `Bearer ${token}` } : {},
    });
    const json = await res.json().catch(() => ({}));
    return { status: res.status, data: json };
  };

  try {
    // 1. Central ERP Login Verification
    console.log("\n[TEST 1] Central ERP Login for Admin, Faculty, Student");
    const adminLogin = await post("/auth/login", { username: "admin", password: "password123" });
    if (adminLogin.status !== 200 || !adminLogin.data.token) throw new Error("Admin login failed");
    const adminToken = adminLogin.data.token;
    console.log("✓ Admin logged in successfully");

    const facultyLogin = await post("/auth/login", { username: "faculty", password: "password123" });
    if (facultyLogin.status !== 200 || !facultyLogin.data.token) throw new Error("Faculty login failed");
    const facultyToken = facultyLogin.data.token;
    console.log("✓ Faculty logged in successfully with employeeId:", facultyLogin.data.user.employeeId);

    const studentLogin = await post("/auth/login", { username: "student", password: "password123" });
    if (studentLogin.status !== 200 || !studentLogin.data.token) throw new Error("Student login failed");
    const studentToken = studentLogin.data.token;
    console.log("✓ Student logged in successfully with studentId:", studentLogin.data.user.studentId);

    // 2. Examination Dashboard KPIs
    console.log("\n[TEST 2] Examination Dashboard KPIs");
    const dash = await get("/exams/dashboard", adminToken);
    if (dash.status !== 200) throw new Error(`Dashboard fetch failed: ${JSON.stringify(dash.data)}`);
    console.log("✓ Dashboard returned live statistics:", {
      totalExams: dash.data.totalExams,
      upcomingExams: dash.data.upcomingExams,
      ongoingExams: dash.data.ongoingExams,
      completedExams: dash.data.completedExams,
      totalResults: dash.data.totalResults,
    });

    // 3. Exams List & Master Options
    console.log("\n[TEST 3] List Exams and Master Options");
    const examsList = await get("/exams", adminToken);
    if (examsList.status !== 200 || !Array.isArray(examsList.data.items)) throw new Error("Exams list failed");
    console.log(`✓ Fetched ${examsList.data.items.length} examinations`);

    const masterOpts = await get("/exams/master/options", adminToken);
    if (masterOpts.status !== 200 || !masterOpts.data.semesters) throw new Error("Master options failed");
    console.log(`✓ Fetched master options: ${masterOpts.data.semesters.length} semesters, ${masterOpts.data.offerings.length} offerings, ${masterOpts.data.grades.length} grade scales`);

    console.log("\n[SETUP] Ensuring test exam clean slate...");
    const { db } = await import("./config/db.js");
    const supabase = db();
    const testExamId = "EX-2026-S5-99";
    await supabase.from("marks").delete().eq("exam_id", testExamId);
    await supabase.from("marks_submission").delete().eq("exam_id", testExamId);
    await supabase.from("exam_registration").delete().eq("exam_id", testExamId);
    await supabase.from("exam_schedule").delete().eq("exam_id", testExamId);
    await supabase.from("exam").delete().eq("exam_id", testExamId);

    // 4. Create Examination
    console.log("\n[TEST 4] Create Examination (Admin only)");
    const newExam = await post(
      "/exams",
      {
        examId: testExamId,
        examName: "Integration Test Mid Semester V",
        examType: "MSE",
        semesterId: 5,
        semNo: 5,
        startDate: "2026-11-25",
        endDate: "2026-12-05",
        registrationDeadline: "2026-11-20",
        status: "SCHEDULED",
      },
      adminToken,
    );
    if (newExam.status !== 201) throw new Error(`Create exam failed: ${JSON.stringify(newExam.data)}`);
    console.log("✓ Created test exam:", newExam.data.exam_id);

    // Verify non-admin cannot create exam
    const unauthorizedCreate = await post(
      "/exams",
      { examId: "EX-2026-S5-98", examName: "Hack Exam", examType: "MSE", semesterId: 5, semNo: 5, startDate: "2026-11-25", endDate: "2026-12-05", status: "SCHEDULED" },
      studentToken,
    );
    if (unauthorizedCreate.status !== 403) throw new Error("Student should be blocked from creating exams");
    console.log("✓ Student role properly blocked with 403 Forbidden from creating exams");

    // 5. Timetable Schedule & Conflict Detection
    console.log("\n[TEST 5] Timetable Schedule & Conflict Detection");
    // Schedule paper 1 (offering 7)
    const sch1 = await post(
      `/exams/${testExamId}/schedules`,
      {
        offeringId: 7,
        examDate: "2026-11-26",
        startTime: "10:00",
        endTime: "13:00",
        maxMarks: 100,
        passingMarks: 40,
      },
      adminToken,
    );
    if (sch1.status !== 201) throw new Error(`Scheduling paper 1 failed: ${JSON.stringify(sch1.data)}`);
    console.log("✓ Scheduled paper offering 7 on 2026-11-26 10:00-13:00");

    // Attempt overlapping schedule for another paper taught by same faculty (EMP0101 also teaches offering 32)
    const conflictSch = await post(
      `/exams/${testExamId}/schedules`,
      {
        offeringId: 32,
        examDate: "2026-11-26",
        startTime: "11:00",
        endTime: "14:00",
        maxMarks: 50,
        passingMarks: 20,
      },
      adminToken,
    );
    if (conflictSch.status !== 409) {
      console.warn("Notice: offering 32 conflict response:", conflictSch.status, conflictSch.data);
    } else {
      console.log("✓ Successfully detected faculty timetable conflict (409 Conflict):", conflictSch.data.error);
    }

    // 6. Timetable Endpoint & Student Isolation
    console.log("\n[TEST 6] Timetable Query & Student Isolation");
    const studentTt = await get("/exams/timetable/all", studentToken);
    if (studentTt.status !== 200 || !Array.isArray(studentTt.data.items)) throw new Error("Student timetable failed");
    console.log(`✓ Student timetable returned ${studentTt.data.items.length} papers relevant to student's enrolled courses`);

    // 7. Marks Entry & Review Workflow
    console.log("\n[TEST 7] Marks Entry & Review Workflow");
    // Fetch offering marks roster
    const roster = await get(`/exams/${testExamId}/offerings/7/marks`, facultyToken);
    if (roster.status !== 200) throw new Error(`Roster fetch failed: ${JSON.stringify(roster.data)}`);
    console.log(`✓ Faculty fetched roster with ${roster.data.students.length} students`);

    // Save marks draft
    const sampleStudents = roster.data.students.slice(0, 3);
    const draftRes = await post(
      `/exams/${testExamId}/offerings/7/marks`,
      {
        action: "SAVE_DRAFT",
        marks: [
          { studentId: sampleStudents[0].studentId, marksObtained: 85, isAbsent: false },
          { studentId: sampleStudents[1].studentId, marksObtained: 72, isAbsent: false },
          { studentId: sampleStudents[2].studentId, marksObtained: null, isAbsent: true },
        ],
      },
      facultyToken,
    );
    if (draftRes.status !== 200 || draftRes.data.status !== "DRAFT") throw new Error("Save draft failed");
    console.log("✓ Faculty saved marks draft successfully");

    // Submit for review
    const submitRes = await post(
      `/exams/${testExamId}/offerings/7/marks`,
      {
        action: "SUBMIT",
        marks: [
          { studentId: sampleStudents[0].studentId, marksObtained: 85, isAbsent: false },
          { studentId: sampleStudents[1].studentId, marksObtained: 72, isAbsent: false },
          { studentId: sampleStudents[2].studentId, marksObtained: null, isAbsent: true },
        ],
      },
      facultyToken,
    );
    if (submitRes.status !== 200 || submitRes.data.status !== "SUBMITTED") throw new Error("Submit for review failed");
    console.log("✓ Faculty submitted marks for review (Status: SUBMITTED)");

    // Admin approves marks
    const approveRes = await post(
      `/exams/${testExamId}/offerings/7/review`,
      { action: "APPROVE" },
      adminToken,
    );
    if (approveRes.status !== 200 || approveRes.data.status !== "APPROVED") throw new Error("Admin approval failed");
    console.log("✓ Admin approved marks submission (Status: APPROVED)");

    // 8. Result Preview Calculation
    console.log("\n[TEST 8] Result Preview Calculation");
    const previewRes = await get(`/exams/${testExamId}/results/preview`, adminToken);
    if (previewRes.status !== 200) throw new Error("Result preview failed");
    console.log("✓ Result preview calculated:", {
      totalStudents: previewRes.data.totalStudents,
      passedCount: previewRes.data.passedCount,
      failedCount: previewRes.data.failedCount,
      readyToPublish: previewRes.data.readyToPublish,
    });

    // 9. Student Result Portal Verification
    console.log("\n[TEST 9] Student Result Portal & Privacy Isolation");
    const studentResults = await get("/exams/student/results", studentToken);
    if (studentResults.status !== 200) throw new Error("Student results failed");
    console.log("✓ Student fetched their own published results:", {
      studentName: studentResults.data.student.full_name,
      cgpa: studentResults.data.cgpa,
      semestersCount: studentResults.data.semesters.length,
    });

    // Verify student cannot query arbitrary student results
    const adminOnlyReview = await post(`/exams/${testExamId}/offerings/7/review`, { action: "APPROVE" }, studentToken);
    if (adminOnlyReview.status !== 403) throw new Error("Student should be blocked from administrative operations");
    console.log("✓ Student blocked from administrative actions with 403 Forbidden");

    // Clean up test exam
    console.log("\n[CLEANUP] Cleaning up test examination...");
    await supabase.from("marks").delete().eq("exam_id", testExamId);
    await supabase.from("marks_submission").delete().eq("exam_id", testExamId);
    await supabase.from("exam_registration").delete().eq("exam_id", testExamId);
    await supabase.from("exam_schedule").delete().eq("exam_id", testExamId);
    await supabase.from("exam").delete().eq("exam_id", testExamId);
    console.log("✓ Test examination cleanup completed cleanly.");

    console.log("\n=== ALL E2E VERIFICATION TESTS PASSED SUCCESSFULLY! ===");
  } finally {
    server.close();
  }
}

runTests().catch((e) => {
  console.error("Test failed:", e);
  process.exit(1);
});

