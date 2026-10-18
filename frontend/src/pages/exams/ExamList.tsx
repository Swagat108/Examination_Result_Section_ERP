import { useEffect, useState, type FormEvent } from "react";
import { StatusBadge } from "../../components/Badge";
import { api } from "../../lib/api";

interface ExamItem {
  exam_id: string;
  exam_name: string;
  exam_type: string;
  semester_id: number;
  sem_no: number;
  registration_deadline: string | null;
  start_date: string;
  end_date: string;
  status: string;
  semester?: {
    term: string;
    academic_year?: {
      label: string;
    };
  };
}

interface SemesterOption {
  semester_id: number;
  term: string;
  is_active: number;
  academic_year?: { label: string };
}

interface CourseOfferingOption {
  offering_id: number;
  course_code: string;
  semester_id: number;
  course?: { course_title: string; credits: number; dept_code: string; course_type: string };
  employee?: { full_name: string; dept_code: string };
}

interface ScheduleItem {
  schedule_id: number;
  exam_id: string;
  offering_id: number;
  exam_date: string;
  start_time: string;
  end_time: string;
  max_marks: number;
  passing_marks: number;
  course_offering?: {
    course_code: string;
    course?: { course_title: string; credits: number; course_type: string };
    employee?: { full_name: string };
  };
}

interface ExamListProps {
  isAdmin: boolean;
  onNavigateToMarks?: (examId: string) => void;
}

export function ExamList({ isAdmin, onNavigateToMarks }: ExamListProps) {
  const [exams, setExams] = useState<ExamItem[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [search, setSearch] = useState("");
  const [filterStatus, setFilterStatus] = useState("");
  const [filterType, setFilterType] = useState("");

  // Master options
  const [semesters, setSemesters] = useState<SemesterOption[]>([]);
  const [offerings, setOfferings] = useState<CourseOfferingOption[]>([]);

  // Modals state
  const [showCreateModal, setShowCreateModal] = useState(false);
  const [editExam, setEditExam] = useState<ExamItem | null>(null);
  const [activeScheduleExam, setActiveScheduleExam] = useState<ExamItem | null>(null);
  const [schedules, setSchedules] = useState<ScheduleItem[]>([]);
  const [scheduleLoading, setScheduleLoading] = useState(false);
  const [scheduleError, setScheduleError] = useState("");

  // Create Form State
  const [createForm, setCreateForm] = useState({
    examId: "",
    examName: "",
    examType: "ESE",
    semesterId: 0,
    semNo: 5,
    startDate: "",
    endDate: "",
    registrationDeadline: "",
    status: "SCHEDULED",
  });
  const [formError, setFormError] = useState("");
  const [formSuccess, setFormSuccess] = useState("");

  // Schedule Form State
  const [newSchedule, setNewSchedule] = useState({
    offeringId: 0,
    examDate: "",
    startTime: "10:00",
    endTime: "13:00",
    maxMarks: 100,
    passingMarks: 40,
  });

  const loadExams = () => {
    setLoading(true);
    let url = "/exams?";
    if (filterStatus) url += `status=${encodeURIComponent(filterStatus)}&`;
    if (filterType) url += `type=${encodeURIComponent(filterType)}&`;
    if (search) url += `search=${encodeURIComponent(search)}&`;

    api<{ items: ExamItem[] }>(url)
      .then((res) => {
        setExams(res.items);
        setError("");
      })
      .catch((err: Error) => setError(err.message))
      .finally(() => setLoading(false));
  };

  useEffect(() => {
    loadExams();
    // Load master options for selects
    if (isAdmin) {
      api<{ semesters: SemesterOption[]; offerings: CourseOfferingOption[] }>("/exams/master/options")
        .then((res) => {
          setSemesters(res.semesters || []);
          setOfferings(res.offerings || []);
          if (res.semesters?.length > 0 && createForm.semesterId === 0) {
            const active = res.semesters.find((s) => s.is_active === 1) || res.semesters[0];
            setCreateForm((prev) => ({ ...prev, semesterId: active.semester_id }));
          }
        })
        .catch(() => {});
    }
  }, [filterStatus, filterType, search]);

  const handleCreateSubmit = async (e: FormEvent) => {
    e.preventDefault();
    setFormError("");
    setFormSuccess("");

    if (!createForm.examId.match(/^EX-[0-9]{4}-S[0-9]-[0-9]{2}$/)) {
      setFormError("Exam ID must follow format EX-YYYY-SX-NN (e.g. EX-2026-S5-02)");
      return;
    }
    if (!createForm.examName.trim()) {
      setFormError("Examination Name is required");
      return;
    }
    if (!createForm.startDate || !createForm.endDate) {
      setFormError("Both start and end dates are required");
      return;
    }
    if (new Date(createForm.endDate) < new Date(createForm.startDate)) {
      setFormError("End date cannot be earlier than start date");
      return;
    }

    try {
      await api("/exams", {
        method: "POST",
        body: {
          examId: createForm.examId,
          examName: createForm.examName,
          examType: createForm.examType,
          semesterId: Number(createForm.semesterId),
          semNo: Number(createForm.semNo),
          startDate: createForm.startDate,
          endDate: createForm.endDate,
          registrationDeadline: createForm.registrationDeadline || null,
          status: createForm.status,
        },
      });

      setFormSuccess("Examination created successfully!");
      loadExams();
      setTimeout(() => {
        setShowCreateModal(false);
        setFormSuccess("");
      }, 1000);
    } catch (err) {
      setFormError((err as Error).message);
    }
  };

  const handleEditSubmit = async (e: FormEvent) => {
    e.preventDefault();
    if (!editExam) return;
    setFormError("");
    setFormSuccess("");

    try {
      await api(`/exams/${editExam.exam_id}`, {
        method: "PUT",
        body: {
          examName: editExam.exam_name,
          examType: editExam.exam_type,
          semNo: editExam.sem_no,
          startDate: editExam.start_date,
          endDate: editExam.end_date,
          registrationDeadline: editExam.registration_deadline || null,
          status: editExam.status,
        },
      });

      setFormSuccess("Examination updated successfully!");
      loadExams();
      setTimeout(() => {
        setEditExam(null);
        setFormSuccess("");
      }, 1000);
    } catch (err) {
      setFormError((err as Error).message);
    }
  };

  const handleDelete = async (examId: string) => {
    if (!confirm(`Are you sure you want to delete examination '${examId}'? This action cannot be undone.`)) {
      return;
    }
    try {
      await api(`/exams/${examId}`, { method: "DELETE" });
      loadExams();
    } catch (err) {
      alert(`Failed to delete: ${(err as Error).message}`);
    }
  };

  // Schedule management modal functions
  const openScheduleManager = (exam: ExamItem) => {
    setActiveScheduleExam(exam);
    setScheduleLoading(true);
    setScheduleError("");
    api<ScheduleItem[]>(`/exams/${exam.exam_id}/schedules`)
      .then((data) => setSchedules(data || []))
      .catch((err: Error) => setScheduleError(err.message))
      .finally(() => setScheduleLoading(false));

    // Preset schedule date
    setNewSchedule((prev) => ({
      ...prev,
      examDate: exam.start_date,
    }));
  };

  const handleAddSchedule = async (e: FormEvent) => {
    e.preventDefault();
    if (!activeScheduleExam) return;
    setScheduleError("");

    if (newSchedule.offeringId === 0) {
      setScheduleError("Please select a course offering to schedule");
      return;
    }
    if (newSchedule.passingMarks > newSchedule.maxMarks) {
      setScheduleError("Passing marks cannot exceed maximum marks");
      return;
    }

    try {
      await api(`/exams/${activeScheduleExam.exam_id}/schedules`, {
        method: "POST",
        body: {
          offeringId: Number(newSchedule.offeringId),
          examDate: newSchedule.examDate,
          startTime: newSchedule.startTime,
          endTime: newSchedule.endTime,
          maxMarks: Number(newSchedule.maxMarks),
          passingMarks: Number(newSchedule.passingMarks),
        },
      });

      // Reload schedules
      const data = await api<ScheduleItem[]>(`/exams/${activeScheduleExam.exam_id}/schedules`);
      setSchedules(data || []);
      setScheduleError("");
    } catch (err) {
      setScheduleError((err as Error).message);
    }
  };

  const handleDeleteSchedule = async (scheduleId: number) => {
    if (!activeScheduleExam) return;
    if (!confirm("Are you sure you want to delete this scheduled examination paper?")) return;
    try {
      await api(`/exams/${activeScheduleExam.exam_id}/schedules/${scheduleId}`, { method: "DELETE" });
      const data = await api<ScheduleItem[]>(`/exams/${activeScheduleExam.exam_id}/schedules`);
      setSchedules(data || []);
    } catch (err) {
      alert(`Failed to delete schedule: ${(err as Error).message}`);
    }
  };

  // Filter offerings for the active exam's semester
  const semesterOfferings = activeScheduleExam
    ? offerings.filter((o) => o.semester_id === activeScheduleExam.semester_id)
    : offerings;

  return (
    <div style={{ display: "flex", flexDirection: "column", gap: "20px" }}>
      {/* Top Filter and Action Bar */}
      <div className="card" style={{ display: "flex", alignItems: "center", justifyContent: "space-between", flexWrap: "wrap", gap: "14px" }}>
        <div style={{ display: "flex", alignItems: "center", gap: "12px", flexWrap: "wrap", flex: 1 }}>
          <input
            type="search"
            placeholder="Search exam name or ID..."
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            style={{ width: "240px" }}
          />

          <select
            value={filterStatus}
            onChange={(e) => setFilterStatus(e.target.value)}
            style={{ width: "170px" }}
          >
            <option value="">All Statuses</option>
            <option value="SCHEDULED">Scheduled</option>
            <option value="REGISTRATION_OPEN">Registration Open</option>
            <option value="ONGOING">Ongoing</option>
            <option value="COMPLETED">Completed</option>
            <option value="RESULTS_PUBLISHED">Results Published</option>
          </select>

          <select
            value={filterType}
            onChange={(e) => setFilterType(e.target.value)}
            style={{ width: "140px" }}
          >
            <option value="">All Types</option>
            <option value="ESE">ESE (End Sem)</option>
            <option value="MSE">MSE (Mid Sem)</option>
            <option value="ISE">ISE (Internal)</option>
            <option value="PRACTICAL">Practical</option>
            <option value="ORAL">Oral</option>
          </select>
        </div>

        {isAdmin && (
          <button
            onClick={() => {
              setFormError("");
              setFormSuccess("");
              setShowCreateModal(true);
            }}
          >
            + Create Examination
          </button>
        )}
      </div>

      {error && <div className="form-alert danger">{error}</div>}

      {/* Examinations Table */}
      <div className="table-wrap">
        <table className="table">
          <thead>
            <tr>
              <th>Exam ID</th>
              <th>Examination Name</th>
              <th>Type</th>
              <th>Academic Term</th>
              <th>Dates</th>
              <th>Status</th>
              <th style={{ textAlign: "right" }}>Actions</th>
            </tr>
          </thead>
          <tbody>
            {loading && (
              <tr>
                <td colSpan={7} className="muted" style={{ textAlign: "center", padding: "30px" }}>
                  Loading examinations...
                </td>
              </tr>
            )}
            {!loading && exams.length === 0 && (
              <tr>
                <td colSpan={7} className="muted" style={{ textAlign: "center", padding: "30px" }}>
                  No examination records match your filter criteria.
                </td>
              </tr>
            )}
            {!loading &&
              exams.map((e) => (
                <tr key={e.exam_id}>
                  <td><strong>{e.exam_id}</strong></td>
                  <td>
                    <div style={{ fontWeight: 600 }}>{e.exam_name}</div>
                    <div className="muted" style={{ fontSize: "12px" }}>
                      Sem {e.sem_no} • Deadline: {e.registration_deadline || "None"}
                    </div>
                  </td>
                  <td><span className="tag">{e.exam_type}</span></td>
                  <td>
                    {e.semester?.academic_year?.label ?? "2026-27"} {e.semester?.term ?? ""}
                  </td>
                  <td>
                    <div style={{ fontSize: "13px" }}>{e.start_date}</div>
                    <div className="muted" style={{ fontSize: "11px" }}>to {e.end_date}</div>
                  </td>
                  <td><StatusBadge status={e.status} /></td>
                  <td style={{ textAlign: "right" }}>
                    <div style={{ display: "inline-flex", gap: "6px" }}>
                      <button
                        className="secondary"
                        style={{ fontSize: "12px", padding: "4px 8px" }}
                        onClick={() => openScheduleManager(e)}
                        title="Manage scheduled papers and timetable"
                      >
                        Schedules
                      </button>
                      {onNavigateToMarks && (
                        <button
                          className="secondary"
                          style={{ fontSize: "12px", padding: "4px 8px" }}
                          onClick={() => onNavigateToMarks(e.exam_id)}
                          title="Enter student marks"
                        >
                          Marks
                        </button>
                      )}
                      {isAdmin && (
                        <>
                          <button
                            className="secondary"
                            style={{ fontSize: "12px", padding: "4px 8px" }}
                            onClick={() => {
                              setEditExam(e);
                              setFormError("");
                              setFormSuccess("");
                            }}
                          >
                            Edit
                          </button>
                          <button
                            className="secondary"
                            style={{ fontSize: "12px", padding: "4px 8px", color: "var(--danger)" }}
                            onClick={() => handleDelete(e.exam_id)}
                          >
                            Delete
                          </button>
                        </>
                      )}
                    </div>
                  </td>
                </tr>
              ))}
          </tbody>
        </table>
      </div>

      {/* CREATE EXAMINATION MODAL */}
      {showCreateModal && (
        <div className="modal-backdrop" onClick={() => setShowCreateModal(false)}>
          <div className="modal-card" onClick={(e) => e.stopPropagation()}>
            <div className="modal-header">
              <h2>Create New Examination Event</h2>
              <button className="icon" onClick={() => setShowCreateModal(false)}>✕</button>
            </div>
            {formError && <div className="form-alert danger">{formError}</div>}
            {formSuccess && <div className="form-alert success">{formSuccess}</div>}

            <form onSubmit={handleCreateSubmit}>
              <div className="form-grid-2">
                <label>
                  Exam ID (EX-YYYY-SX-NN)
                  <input
                    type="text"
                    required
                    placeholder="e.g. EX-2026-S5-02"
                    value={createForm.examId}
                    onChange={(e) => setCreateForm({ ...createForm, examId: e.target.value.toUpperCase() })}
                  />
                </label>
                <label>
                  Exam Type
                  <select
                    value={createForm.examType}
                    onChange={(e) => setCreateForm({ ...createForm, examType: e.target.value })}
                  >
                    <option value="ESE">End Semester Exam (ESE)</option>
                    <option value="MSE">Mid Semester Exam (MSE)</option>
                    <option value="ISE">In Semester Exam (ISE)</option>
                    <option value="PRACTICAL">Practical Examination</option>
                    <option value="ORAL">Oral Examination</option>
                  </select>
                </label>
              </div>

              <label>
                Examination Title
                <input
                  type="text"
                  required
                  placeholder="e.g. End Semester Examination - Semester V (2026-27)"
                  value={createForm.examName}
                  onChange={(e) => setCreateForm({ ...createForm, examName: e.target.value })}
                />
              </label>

              <div className="form-grid-2">
                <label>
                  Target Semester
                  <select
                    value={createForm.semesterId}
                    onChange={(e) => {
                      const sid = Number(e.target.value);
                      setCreateForm({ ...createForm, semesterId: sid });
                    }}
                  >
                    {semesters.map((s) => (
                      <option key={s.semester_id} value={s.semester_id}>
                        {s.academic_year?.label} {s.term} Term (Sem ID: {s.semester_id}) {s.is_active ? "★ Active" : ""}
                      </option>
                    ))}
                  </select>
                </label>
                <label>
                  Semester Number (1 - 8)
                  <input
                    type="number"
                    min={1}
                    max={8}
                    required
                    value={createForm.semNo}
                    onChange={(e) => setCreateForm({ ...createForm, semNo: Number(e.target.value) })}
                  />
                </label>
              </div>

              <div className="form-grid-2">
                <label>
                  Start Date
                  <input
                    type="date"
                    required
                    value={createForm.startDate}
                    onChange={(e) => setCreateForm({ ...createForm, startDate: e.target.value })}
                  />
                </label>
                <label>
                  End Date
                  <input
                    type="date"
                    required
                    value={createForm.endDate}
                    onChange={(e) => setCreateForm({ ...createForm, endDate: e.target.value })}
                  />
                </label>
              </div>

              <div className="form-grid-2">
                <label>
                  Registration Deadline
                  <input
                    type="date"
                    value={createForm.registrationDeadline}
                    onChange={(e) => setCreateForm({ ...createForm, registrationDeadline: e.target.value })}
                  />
                </label>
                <label>
                  Initial Status
                  <select
                    value={createForm.status}
                    onChange={(e) => setCreateForm({ ...createForm, status: e.target.value })}
                  >
                    <option value="SCHEDULED">Scheduled</option>
                    <option value="REGISTRATION_OPEN">Registration Open</option>
                    <option value="ONGOING">Ongoing</option>
                  </select>
                </label>
              </div>

              <div className="modal-actions">
                <button type="button" className="secondary" onClick={() => setShowCreateModal(false)}>
                  Cancel
                </button>
                <button type="submit">Create Examination</button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* EDIT EXAMINATION MODAL */}
      {editExam && (
        <div className="modal-backdrop" onClick={() => setEditExam(null)}>
          <div className="modal-card" onClick={(e) => e.stopPropagation()}>
            <div className="modal-header">
              <h2>Edit Examination: {editExam.exam_id}</h2>
              <button className="icon" onClick={() => setEditExam(null)}>✕</button>
            </div>
            {formError && <div className="form-alert danger">{formError}</div>}
            {formSuccess && <div className="form-alert success">{formSuccess}</div>}

            <form onSubmit={handleEditSubmit}>
              <label>
                Examination Title
                <input
                  type="text"
                  required
                  value={editExam.exam_name}
                  onChange={(e) => setEditExam({ ...editExam, exam_name: e.target.value })}
                />
              </label>

              <div className="form-grid-2">
                <label>
                  Exam Type
                  <select
                    value={editExam.exam_type}
                    onChange={(e) => setEditExam({ ...editExam, exam_type: e.target.value })}
                  >
                    <option value="ESE">End Semester Exam (ESE)</option>
                    <option value="MSE">Mid Semester Exam (MSE)</option>
                    <option value="ISE">In Semester Exam (ISE)</option>
                    <option value="PRACTICAL">Practical Examination</option>
                    <option value="ORAL">Oral Examination</option>
                  </select>
                </label>
                <label>
                  Semester No
                  <input
                    type="number"
                    min={1}
                    max={8}
                    required
                    value={editExam.sem_no}
                    onChange={(e) => setEditExam({ ...editExam, sem_no: Number(e.target.value) })}
                  />
                </label>
              </div>

              <div className="form-grid-2">
                <label>
                  Start Date
                  <input
                    type="date"
                    required
                    value={editExam.start_date}
                    onChange={(e) => setEditExam({ ...editExam, start_date: e.target.value })}
                  />
                </label>
                <label>
                  End Date
                  <input
                    type="date"
                    required
                    value={editExam.end_date}
                    onChange={(e) => setEditExam({ ...editExam, end_date: e.target.value })}
                  />
                </label>
              </div>

              <div className="form-grid-2">
                <label>
                  Registration Deadline
                  <input
                    type="date"
                    value={editExam.registration_deadline || ""}
                    onChange={(e) => setEditExam({ ...editExam, registration_deadline: e.target.value || null })}
                  />
                </label>
                <label>
                  Status
                  <select
                    value={editExam.status}
                    onChange={(e) => setEditExam({ ...editExam, status: e.target.value })}
                  >
                    <option value="SCHEDULED">Scheduled</option>
                    <option value="REGISTRATION_OPEN">Registration Open</option>
                    <option value="ONGOING">Ongoing</option>
                    <option value="COMPLETED">Completed</option>
                    <option value="RESULTS_PUBLISHED">Results Published</option>
                  </select>
                </label>
              </div>

              <div className="modal-actions">
                <button type="button" className="secondary" onClick={() => setEditExam(null)}>
                  Cancel
                </button>
                <button type="submit">Save Changes</button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* SCHEDULES & TIMETABLE CONFLICT MANAGER MODAL */}
      {activeScheduleExam && (
        <div className="modal-backdrop" onClick={() => setActiveScheduleExam(null)}>
          <div className="modal-card modal-lg" onClick={(e) => e.stopPropagation()}>
            <div className="modal-header">
              <div>
                <h2>Exam Papers & Timetable Schedule</h2>
                <div className="muted" style={{ fontSize: "13px" }}>
                  {activeScheduleExam.exam_id} • {activeScheduleExam.exam_name}
                </div>
              </div>
              <button className="icon" onClick={() => setActiveScheduleExam(null)}>✕</button>
            </div>

            {scheduleError && <div className="form-alert danger">{scheduleError}</div>}

            {/* Add Paper Schedule Form (Admin) */}
            {isAdmin && (
              <div style={{ background: "var(--bg)", padding: "16px", borderRadius: "var(--radius-control)", marginBottom: "20px" }}>
                <h3 style={{ margin: "0 0 12px", fontSize: "15px" }}>Schedule a Course Paper (Conflict Detection Active)</h3>
                <form onSubmit={handleAddSchedule}>
                  <div className="form-grid-2">
                    <label>
                      Course Offering
                      <select
                        value={newSchedule.offeringId}
                        onChange={(e) => {
                          const offId = Number(e.target.value);
                          const off = offerings.find((o) => o.offering_id === offId);
                          const isTheory = off?.course?.course_type === "THEORY";
                          setNewSchedule({
                            ...newSchedule,
                            offeringId: offId,
                            maxMarks: isTheory ? 100 : 50,
                            passingMarks: isTheory ? 40 : 20,
                          });
                        }}
                      >
                        <option value={0}>-- Select Course Offering --</option>
                        {semesterOfferings.map((o) => (
                          <option key={o.offering_id} value={o.offering_id}>
                            {o.course_code} - {o.course?.course_title} ({o.course?.course_type}) • {o.employee?.full_name || "Unassigned"}
                          </option>
                        ))}
                      </select>
                    </label>

                    <label>
                      Exam Date
                      <input
                        type="date"
                        required
                        value={newSchedule.examDate}
                        onChange={(e) => setNewSchedule({ ...newSchedule, examDate: e.target.value })}
                      />
                    </label>
                  </div>

                  <div className="form-grid-4" style={{ display: "grid", gridTemplateColumns: "repeat(auto-fit, minmax(130px, 1fr))", gap: "10px" }}>
                    <label>
                      Start Time
                      <input
                        type="time"
                        required
                        value={newSchedule.startTime}
                        onChange={(e) => setNewSchedule({ ...newSchedule, startTime: e.target.value })}
                      />
                    </label>
                    <label>
                      End Time
                      <input
                        type="time"
                        required
                        value={newSchedule.endTime}
                        onChange={(e) => setNewSchedule({ ...newSchedule, endTime: e.target.value })}
                      />
                    </label>
                    <label>
                      Max Marks
                      <input
                        type="number"
                        min={1}
                        max={200}
                        required
                        value={newSchedule.maxMarks}
                        onChange={(e) => setNewSchedule({ ...newSchedule, maxMarks: Number(e.target.value) })}
                      />
                    </label>
                    <label>
                      Passing Marks
                      <input
                        type="number"
                        min={1}
                        max={newSchedule.maxMarks}
                        required
                        value={newSchedule.passingMarks}
                        onChange={(e) => setNewSchedule({ ...newSchedule, passingMarks: Number(e.target.value) })}
                      />
                    </label>
                  </div>

                  <div style={{ marginTop: "12px", display: "flex", justifyContent: "flex-end" }}>
                    <button type="submit" style={{ fontSize: "13px", padding: "6px 14px" }}>
                      + Add / Update Schedule
                    </button>
                  </div>
                </form>
              </div>
            )}

            {/* Scheduled Papers Table */}
            <h3 style={{ fontSize: "15px", margin: "16px 0 8px" }}>Currently Scheduled Papers ({schedules.length})</h3>
            <div className="table-wrap">
              <table className="table">
                <thead>
                  <tr>
                    <th>Date</th>
                    <th>Time</th>
                    <th>Course</th>
                    <th>Faculty</th>
                    <th>Marks</th>
                    {isAdmin && <th style={{ textAlign: "right" }}>Action</th>}
                  </tr>
                </thead>
                <tbody>
                  {scheduleLoading && (
                    <tr>
                      <td colSpan={6} className="muted" style={{ textAlign: "center", padding: "20px" }}>Loading schedules...</td>
                    </tr>
                  )}
                  {!scheduleLoading && schedules.length === 0 && (
                    <tr>
                      <td colSpan={6} className="muted" style={{ textAlign: "center", padding: "20px" }}>No papers scheduled yet for this examination.</td>
                    </tr>
                  )}
                  {!scheduleLoading &&
                    schedules.map((s) => (
                      <tr key={s.schedule_id}>
                        <td><strong>{s.exam_date}</strong></td>
                        <td>{s.start_time.slice(0, 5)} - {s.end_time.slice(0, 5)}</td>
                        <td>
                          <div><b>{s.course_offering?.course_code}</b></div>
                          <div className="muted" style={{ fontSize: "12px" }}>
                            {s.course_offering?.course?.course_title}
                          </div>
                        </td>
                        <td>{s.course_offering?.employee?.full_name || "Unassigned"}</td>
                        <td>
                          <span className="tag" style={{ background: "var(--accent-soft)", color: "var(--accent)" }}>
                            Pass: {s.passing_marks} / {s.max_marks}
                          </span>
                        </td>
                        {isAdmin && (
                          <td style={{ textAlign: "right" }}>
                            <button
                              className="secondary"
                              style={{ color: "var(--danger)", fontSize: "12px", padding: "3px 8px" }}
                              onClick={() => handleDeleteSchedule(s.schedule_id)}
                            >
                              Delete
                            </button>
                          </td>
                        )}
                      </tr>
                    ))}
                </tbody>
              </table>
            </div>

            <div className="modal-actions">
              <button className="secondary" onClick={() => setActiveScheduleExam(null)}>
                Close
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
