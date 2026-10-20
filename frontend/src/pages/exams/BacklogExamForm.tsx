import { useEffect, useState } from "react";
import { Badge, StatusBadge } from "../../components/Badge";
import { useAuth } from "../../auth/AuthContext";
import { api } from "../../lib/api";

interface FailedCourse {
  resultId: number;
  offeringId: number;
  courseCode: string;
  courseTitle: string;
  credits: number;
  courseType: string;
  totalMarks: number;
  maxMarks: number;
  percentage: number;
  grade: string;
  semesterTerm: string;
  academicYear: string;
  isAlreadySubmitted?: boolean;
}

interface AvailableExam {
  exam_id: string;
  exam_name: string;
  exam_type: string;
  semester_id: number;
  sem_no: number;
  start_date: string;
  end_date: string;
  registration_deadline?: string;
  status: string;
}

interface BacklogFormItem {
  item_id: number;
  form_id: number;
  offering_id: number;
  course_code: string;
  course_title: string;
  semester_term: string;
  credits: number;
  previous_grade: string;
  previous_marks: number;
  attempt_no: number;
  fee_amount: number;
}

interface BacklogForm {
  form_id: number;
  form_no: string;
  student_id: string;
  exam_id: string;
  academic_year: string;
  total_subjects: number;
  total_credits: number;
  base_fee: number;
  per_subject_fee: number;
  total_fee: number;
  payment_mode: string;
  payment_status: string;
  payment_reference: string;
  status: string;
  remarks: string;
  reviewed_by?: string;
  reviewed_at?: string;
  created_at: string;
  student?: {
    student_id: string;
    full_name: string;
    enrollment_no: string;
    email?: string;
    program?: {
      program_name: string;
      program_code: string;
    };
  };
  exam?: {
    exam_id: string;
    exam_name: string;
    exam_type: string;
    sem_no?: number;
    start_date?: string;
    end_date?: string;
  };
  items?: BacklogFormItem[];
}

interface FailedStudentSummary {
  studentId: string;
  fullName: string;
  enrollmentNo: string;
  email: string;
  admissionYear: number;
  programName: string;
  programCode: string;
  failedCoursesCount: number;
  failedCourses: FailedCourse[];
  forms?: BacklogForm[];
  latestForm?: BacklogForm | null;
}

interface BacklogStats {
  totalFailedCourses: number;
  totalFailedStudents: number;
  totalForms: number;
  pendingReview: number;
  approvedForms: number;
  totalFeesCollected: number;
}

interface BacklogExamFormProps {
  isAdmin: boolean;
  isFaculty?: boolean;
}

export function BacklogExamForm({ isAdmin, isFaculty }: BacklogExamFormProps) {
  const { user } = useAuth();
  const isStudent = Boolean(user?.roles.includes("STUDENT"));

  // Default active student ID
  const initialStudentId = user?.studentId || "2024ETC0018";
  const [activeStudentId, setActiveStudentId] = useState<string>(initialStudentId);

  // Mode tabs: for students vs admin
  const [activeSubTab, setActiveSubTab] = useState<string>(isStudent ? "apply" : "forms_list");

  // Data states
  const [stats, setStats] = useState<BacklogStats | null>(null);
  const [failedCourses, setFailedCourses] = useState<FailedCourse[]>([]);
  const [availableExams, setAvailableExams] = useState<AvailableExam[]>([]);
  const [existingForms, setExistingForms] = useState<BacklogForm[]>([]);
  const [allForms, setAllForms] = useState<BacklogForm[]>([]);
  const [failedStudents, setFailedStudents] = useState<FailedStudentSummary[]>([]);
  const [studentProfile, setStudentProfile] = useState<any>(null);

  // Form input states
  const [selectedOfferings, setSelectedOfferings] = useState<number[]>([]);
  const [targetExamId, setTargetExamId] = useState<string>("");
  const [paymentMode, setPaymentMode] = useState<string>("ONLINE");
  const [declarationAccepted, setDeclarationAccepted] = useState(false);
  const [studentRemarks, setStudentRemarks] = useState("");

  // Loading & error
  const [loading, setLoading] = useState(false);
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState("");
  const [successMsg, setSuccessMsg] = useState("");

  // Print Slip Modal / View Modal
  const [selectedFormForSlip, setSelectedFormForSlip] = useState<BacklogForm | null>(null);
  const [showSlipModal, setShowSlipModal] = useState(false);

  // Admin Review Modal
  const [selectedFormForReview, setSelectedFormForReview] = useState<BacklogForm | null>(null);
  const [reviewStatus, setReviewStatus] = useState<"APPROVED" | "REJECTED" | "UNDER_REVIEW">("APPROVED");
  const [reviewPaymentStatus, setReviewPaymentStatus] = useState<"PAID" | "PENDING">("PAID");
  const [reviewRemarks, setReviewRemarks] = useState("");
  const [showReviewModal, setShowReviewModal] = useState(false);

  // Filters for Admin Forms list
  const [statusFilter, setStatusFilter] = useState("ALL");
  const [searchFilter, setSearchFilter] = useState("");

  // Demo candidates with known backlogs for testing convenience
  const DEMO_FAILED_CANDIDATES = [
    { id: "2024ETC0018", name: "Chandane Manoj Bhagwan", roll: "F24ET018", backlogs: 1, course: "ETC203 Analog Comm." },
    { id: "2024ETC0075", name: "Chothave Shravani Sakharam", roll: "F24ET075", backlogs: 1, course: "ETC202 Signals & Sys." },
    { id: "2024ETC0077", name: "Golangade Paras Deepak", roll: "F24ET077", backlogs: 1, course: "ETC203 Analog Comm." },
    { id: "2024ETC0145", name: "Shinde Shruti Bapu", roll: "F24ET145", backlogs: 1, course: "ETC201 Analog Circuits" },
    { id: "2024ETC0174", name: "Thag Divya Vijay", roll: "F24ET174", backlogs: 1, course: "ETC206 Microcontroller Lab" },
    { id: "2024ETC0003", name: "Bansod Swarali Bipin (Regular - 0 Backlogs)", roll: "F24ET003", backlogs: 0, course: "All Passed" },
  ];

  // Load KPI Stats
  const loadStats = () => {
    api<BacklogStats>("/exams/backlog/stats")
      .then(setStats)
      .catch((err) => console.warn("Failed to load backlog stats:", err));
  };

  // Load eligible courses for candidate
  const loadCandidateData = (sid: string) => {
    setLoading(true);
    setError("");
    api<{
      student: any;
      failedCourses: FailedCourse[];
      availableExams: AvailableExam[];
      existingForms: BacklogForm[];
    }>(`/exams/backlog/eligible-courses/${sid}`)
      .then((res) => {
        setStudentProfile(res.student);
        setFailedCourses(res.failedCourses);
        setAvailableExams(res.availableExams);
        setExistingForms(res.existingForms);

        // Pre-select target exam
        if (res.availableExams && res.availableExams.length > 0) {
          setTargetExamId(res.availableExams[0].exam_id);
        }

        // Auto-select unsubmitted failed offerings
        const unsubmitted = res.failedCourses
          .filter((c) => !c.isAlreadySubmitted)
          .map((c) => c.offeringId);
        setSelectedOfferings(unsubmitted);
      })
      .catch((err: Error) => {
        setError(err.message);
      })
      .finally(() => setLoading(false));
  };

  // Load all submitted forms (for admin)
  const loadAllForms = () => {
    api<{ items: BacklogForm[] }>(`/exams/backlog/forms?status=${statusFilter}`)
      .then((res) => setAllForms(res.items || []))
      .catch((err) => console.warn("Failed to load backlog forms:", err));
  };

  // Load failed students registry (for admin)
  const loadFailedStudentsRegistry = () => {
    api<{ students: FailedStudentSummary[] }>("/exams/backlog/failed-students")
      .then((res) => setFailedStudents(res.students || []))
      .catch((err) => console.warn("Failed to load failed students registry:", err));
  };

  useEffect(() => {
    loadStats();
    if (isStudent || activeStudentId) {
      loadCandidateData(activeStudentId);
    }
    if (isAdmin || isFaculty) {
      loadAllForms();
      loadFailedStudentsRegistry();
    }
  }, [activeStudentId, isAdmin, isFaculty, isStudent, statusFilter]);

  // Handle student switcher
  const handleSelectStudent = (sid: string) => {
    setActiveStudentId(sid);
    setSuccessMsg("");
    setError("");
    setSelectedOfferings([]);
    loadCandidateData(sid);
  };

  // Toggle offering selection
  const handleToggleOffering = (offeringId: number) => {
    setSelectedOfferings((prev) =>
      prev.includes(offeringId)
        ? prev.filter((id) => id !== offeringId)
        : [...prev, offeringId]
    );
  };

  const handleSelectAll = () => {
    setSelectedOfferings(failedCourses.map((c) => c.offeringId));
  };

  const handleDeselectAll = () => {
    setSelectedOfferings([]);
  };

  // Live Fee Calculation
  const BASE_FEE = 250;
  const PER_SUBJECT_FEE = 350;
  const selectedCount = selectedOfferings.length;
  const totalPayableFee = selectedCount > 0 ? BASE_FEE + (PER_SUBJECT_FEE * selectedCount) : 0;

  // Form Submit Handler
  const handleSubmitForm = async (e: React.FormEvent) => {
    e.preventDefault();
    setError("");
    setSuccessMsg("");

    if (!targetExamId) {
      setError("Please select the target examination event.");
      return;
    }
    if (selectedOfferings.length === 0) {
      setError("Please select at least one backlog course to re-appear for.");
      return;
    }
    if (!declarationAccepted) {
      setError("You must accept the student declaration before submitting.");
      return;
    }

    setSubmitting(true);
    try {
      const res = await api<{ message: string; form: BacklogForm; items: BacklogFormItem[] }>(
        "/exams/backlog/forms",
        {
          method: "POST",
          body: {
            studentId: activeStudentId,
            examId: targetExamId,
            offeringIds: selectedOfferings,
            paymentMode,
            declarationAccepted: true,
            remarks: studentRemarks,
            autoApprove: isAdmin, // if admin is submitting on-behalf, can auto-approve
          },
        }
      );

      setSuccessMsg(`Backlog Exam Form ${res.form.form_no} submitted successfully!`);
      // Reload candidate data & stats
      loadCandidateData(activeStudentId);
      loadStats();
      if (isAdmin || isFaculty) {
        loadAllForms();
        loadFailedStudentsRegistry();
      }

      // Open print slip preview
      handleViewSlip(res.form.form_id);
    } catch (err: any) {
      setError(err.message || "Failed to submit backlog examination form.");
    } finally {
      setSubmitting(false);
    }
  };

  // View / Print Official Slip
  const handleViewSlip = (formId: number) => {
    api<{ form: BacklogForm; items: BacklogFormItem[] }>(`/exams/backlog/forms/${formId}`)
      .then((res) => {
        setSelectedFormForSlip({
          ...res.form,
          items: res.items,
        });
        setShowSlipModal(true);
      })
      .catch((err) => alert(`Failed to load form details: ${err.message}`));
  };

  // Print slip action
  const handlePrintSlip = () => {
    const originalTitle = document.title;
    if (selectedFormForSlip) {
      document.title = `${selectedFormForSlip.form_no}-Backlog-Exam-Form`;
    }
    window.print();
    window.setTimeout(() => {
      document.title = originalTitle;
    }, 1000);
  };

  // Open Admin Review Modal
  const handleOpenReview = (form: BacklogForm) => {
    setSelectedFormForReview(form);
    setReviewStatus(form.status === "REJECTED" ? "REJECTED" : "APPROVED");
    setReviewPaymentStatus(form.payment_status === "PAID" ? "PAID" : "PAID");
    setReviewRemarks(form.remarks || "");
    setShowReviewModal(true);
  };

  // Submit Admin Review
  const handleSubmitReview = async () => {
    if (!selectedFormForReview) return;
    try {
      await api(`/exams/backlog/forms/${selectedFormForReview.form_id}/review`, {
        method: "POST",
        body: {
          status: reviewStatus,
          paymentStatus: reviewPaymentStatus,
          remarks: reviewRemarks,
        },
      });
      setShowReviewModal(false);
      loadAllForms();
      loadStats();
      loadFailedStudentsRegistry();
      if (activeStudentId) loadCandidateData(activeStudentId);
    } catch (err: any) {
      alert(`Review update failed: ${err.message}`);
    }
  };

  // Delete Form
  const handleDeleteForm = async (formId: number, formNo: string) => {
    if (!confirm(`Are you sure you want to delete backlog form ${formNo}?`)) return;
    try {
      await api(`/exams/backlog/forms/${formId}`, { method: "DELETE" });
      loadAllForms();
      loadStats();
      if (activeStudentId) loadCandidateData(activeStudentId);
    } catch (err: any) {
      alert(`Delete failed: ${err.message}`);
    }
  };

  return (
    <div style={{ display: "flex", flexDirection: "column", gap: "24px" }}>
      {/* Printable University Official Form Header (Only shown when printing) */}
      {selectedFormForSlip && (
        <div className="print-only" style={{ display: "none" }}>
          <div style={{ textAlign: "center", borderBottom: "2px solid #111", paddingBottom: "12px", marginBottom: "16px" }}>
            <h2 style={{ margin: "0 0 4px", fontSize: "20pt", fontWeight: "bold", textTransform: "uppercase" }}>
              University of Engineering & Technology
            </h2>
            <div style={{ fontSize: "11pt", color: "#333" }}>Office of the Controller of Examinations • Autonomous Division</div>
            <div style={{ fontSize: "12pt", fontWeight: "bold", marginTop: "6px", textDecoration: "underline" }}>
              APPLICATION FORM FOR RE-EXAMINATION / BACKLOG CLEARANCE (AUTONOMOUS)
            </div>
            <div style={{ fontSize: "10pt", color: "#555", marginTop: "2px" }}>
              Academic Session {selectedFormForSlip.academic_year} • Form Ref: <b>{selectedFormForSlip.form_no}</b>
            </div>
          </div>
        </div>
      )}

      {/* Top Overview Banner & KPI Stats Row */}
      <div className="result-card-banner no-print">
        <div style={{ display: "flex", justifyContent: "space-between", alignItems: "flex-start", flexWrap: "wrap", gap: "16px" }}>
          <div>
            <span className="badge danger" style={{ marginBottom: "8px", fontWeight: 700 }}>
              EXAMINATION CELL • REMEDIAL & BACKLOG PORTAL
            </span>
            <h2 style={{ fontSize: "24px", color: "#fff", margin: "4px 0" }}>
              Exam Form for Failed Students (Backlog / Supplementary)
            </h2>
            <p style={{ color: "#dcebe4", fontSize: "14px", margin: "4px 0 0", maxWidth: "700px" }}>
              Official re-examination application window for candidates with unsatisfied academic course requirements (Grade F / Incomplete).
              Eligible students may select pending courses, verify examination fees, and complete submission for upcoming examination session.
            </p>
          </div>

          <div style={{ display: "flex", gap: "10px", alignItems: "center" }}>
            <span className="tag" style={{ background: "rgba(255,255,255,0.2)", color: "#fff" }}>
              Session: 2026-27 (Odd Term)
            </span>
            <span className="tag" style={{ background: "#fef3c7", color: "#92400e", fontWeight: 700 }}>
              Fee: ₹250 Base + ₹350/Course
            </span>
          </div>
        </div>

        {/* Live Metrics Grid */}
        <div className="result-stat-row">
          <div className="result-stat-box">
            <small>Total Failed Students</small>
            <strong style={{ color: "var(--danger)" }}>{stats?.totalFailedStudents ?? 14}</strong>
          </div>
          <div className="result-stat-box">
            <small>Active Failed Courses</small>
            <strong style={{ color: "#fbbf24" }}>{stats?.totalFailedCourses ?? 17}</strong>
          </div>
          <div className="result-stat-box">
            <small>Forms Submitted</small>
            <strong style={{ color: "#fff" }}>{stats?.totalForms ?? 0}</strong>
          </div>
          <div className="result-stat-box">
            <small>Forms Approved</small>
            <strong style={{ color: "#86efac" }}>{stats?.approvedForms ?? 0}</strong>
          </div>
          <div className="result-stat-box">
            <small>Backlog Fees Collected</small>
            <strong style={{ color: "#fff" }}>₹{Number(stats?.totalFeesCollected ?? 0).toLocaleString()}</strong>
          </div>
        </div>
      </div>

      {/* Navigation Sub-Tabs Bar */}
      <div className="card no-print" style={{ padding: "8px 12px", display: "flex", justifyContent: "space-between", alignItems: "center", flexWrap: "wrap", gap: "10px" }}>
        <div style={{ display: "flex", gap: "8px", flexWrap: "wrap" }}>
          <button
            className={activeSubTab === "apply" ? "" : "secondary"}
            onClick={() => setActiveSubTab("apply")}
            style={{ fontWeight: 600 }}
          >
            ✍️ Fill Backlog Exam Form
          </button>

          <button
            className={activeSubTab === "candidate_history" ? "" : "secondary"}
            onClick={() => setActiveSubTab("candidate_history")}
            style={{ fontWeight: 600 }}
          >
            📄 My Submitted Forms & Slips ({existingForms.length})
          </button>

          {(!isStudent || isAdmin) && (
            <>
              <button
                className={activeSubTab === "forms_list" ? "" : "secondary"}
                onClick={() => setActiveSubTab("forms_list")}
                style={{ fontWeight: 600 }}
              >
                📋 All Backlog Submissions ({allForms.length})
              </button>

              <button
                className={activeSubTab === "registry" ? "" : "secondary"}
                onClick={() => setActiveSubTab("registry")}
                style={{ fontWeight: 600 }}
              >
                ⚠️ Failed Students Registry ({failedStudents.length})
              </button>
            </>
          )}
        </div>

        {/* Demo Candidate Switcher */}
        <div style={{ display: "flex", alignItems: "center", gap: "8px" }}>
          <label htmlFor="quick-demo-student" style={{ margin: 0, fontSize: "13px", fontWeight: 700, color: "var(--muted)" }}>
            Quick Demo Student:
          </label>
          <select
            id="quick-demo-student"
            value={activeStudentId}
            onChange={(e) => handleSelectStudent(e.target.value)}
            style={{ width: "auto", minWidth: "240px", fontSize: "13px", padding: "6px 10px" }}
          >
            {DEMO_FAILED_CANDIDATES.map((cand) => (
              <option key={cand.id} value={cand.id}>
                {cand.roll} - {cand.name} ({cand.backlogs} Backlog: {cand.course})
              </option>
            ))}
          </select>
        </div>
      </div>

      {/* =========================================================================
          SUB-TAB 1: FILL EXAM FORM FOR FAILED STUDENTS
          ========================================================================= */}
      {activeSubTab === "apply" && (
        <div style={{ display: "flex", flexDirection: "column", gap: "20px" }}>
          {/* Candidate Profile Details Card */}
          <div className="card" style={{ padding: "18px 22px" }}>
            <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", flexWrap: "wrap", gap: "12px", borderBottom: "1px solid var(--border)", paddingBottom: "12px", marginBottom: "16px" }}>
              <div style={{ display: "flex", alignItems: "center", gap: "14px" }}>
                <div style={{ width: "46px", height: "46px", borderRadius: "50%", background: "var(--primary)", color: "#fff", display: "grid", placeItems: "center", fontSize: "18px", fontWeight: 700 }}>
                  {studentProfile?.full_name?.charAt(0) || "S"}
                </div>
                <div>
                  <h3 style={{ margin: 0, fontSize: "18px" }}>
                    {studentProfile?.full_name || "Loading candidate profile..."}
                  </h3>
                  <div style={{ fontSize: "13px", color: "var(--muted)", marginTop: "2px" }}>
                    Student ID: <b>{studentProfile?.student_id || activeStudentId}</b> • Enrollment / PRN: <b>{studentProfile?.enrollment_no || "--"}</b>
                  </div>
                </div>
              </div>

              <div style={{ textAlign: "right" }}>
                <span className="badge" style={{ background: "var(--bg)", border: "1px solid var(--border)", color: "var(--text)" }}>
                  Program: {studentProfile?.program?.program_name || "B.Tech"} ({studentProfile?.program?.program_code || "ETC"})
                </span>
                <div style={{ fontSize: "12px", color: "var(--muted)", marginTop: "4px" }}>
                  Admitted Batch: <b>{studentProfile?.admission_year || "2024"}</b>
                </div>
              </div>
            </div>

            {/* Backlog Alert Notice */}
            {failedCourses.length > 0 ? (
              <div className="form-alert warn" style={{ display: "flex", alignItems: "center", justifyContent: "space-between", flexWrap: "wrap", gap: "10px" }}>
                <div>
                  <strong>⚠️ Backlog Notice:</strong> You currently have{" "}
                  <b>{failedCourses.length} failed course(s)</b> requiring re-examination to complete academic graduation requirements.
                </div>
                <span className="tag" style={{ background: "#fef3c7", color: "#92400e", fontWeight: 700 }}>
                  Re-examination Term Open
                </span>
              </div>
            ) : (
              <div className="form-alert success">
                <strong>🎉 All Clear!</strong> This student has passed all examinations and currently has 0 backlogs.
                If you wish to test submitting a form for a student with backlogs, select one of the failed candidates from the "Quick Demo Student" dropdown above.
              </div>
            )}
          </div>

          {/* Form Alert Banners */}
          {error && <div className="form-alert danger">{error}</div>}
          {successMsg && <div className="form-alert success">{successMsg}</div>}

          {/* Backlog Subjects Selection & Fee Form */}
          {failedCourses.length > 0 && (
            <form onSubmit={handleSubmitForm} style={{ display: "flex", flexDirection: "column", gap: "20px" }}>
              {/* Step 1: Target Exam Selection */}
              <div className="card" style={{ padding: "20px" }}>
                <h3 style={{ margin: "0 0 12px", fontSize: "16px", display: "flex", alignItems: "center", gap: "8px" }}>
                  <span style={{ width: "24px", height: "24px", borderRadius: "50%", background: "var(--primary)", color: "#fff", display: "inline-grid", placeItems: "center", fontSize: "12px" }}>1</span>
                  Select Target Examination Event
                </h3>
                <p className="muted" style={{ margin: "0 0 14px", fontSize: "13px" }}>
                  Choose the active or upcoming university examination session in which you intend to re-appear for your failed course(s).
                </p>

                <div className="form-grid-2">
                  <div>
                    <label htmlFor="target-exam-id"><strong>Examination Event *</strong></label>
                    <select
                      id="target-exam-id"
                      value={targetExamId}
                      onChange={(e) => setTargetExamId(e.target.value)}
                      required
                    >
                      {availableExams.map((ex) => (
                        <option key={ex.exam_id} value={ex.exam_id}>
                          {ex.exam_name} ({ex.exam_id}) • Dates: {ex.start_date} to {ex.end_date} [{ex.status}]
                        </option>
                      ))}
                    </select>
                  </div>

                  <div>
                    <label><strong>Examination Schedule Window</strong></label>
                    <input
                      type="text"
                      readOnly
                      disabled
                      value={
                        availableExams.find((e) => e.exam_id === targetExamId)
                          ? `Commencing ${availableExams.find((e) => e.exam_id === targetExamId)?.start_date} • Concluding ${availableExams.find((e) => e.exam_id === targetExamId)?.end_date}`
                          : "Scheduled semester window"
                      }
                      style={{ background: "var(--bg)" }}
                    />
                  </div>
                </div>
              </div>

              {/* Step 2: Failed Subjects to Attempt */}
              <div className="card" style={{ padding: "0", overflow: "hidden" }}>
                <div style={{ padding: "18px 22px", borderBottom: "1px solid var(--border)", display: "flex", justifyContent: "space-between", alignItems: "center", flexWrap: "wrap", gap: "10px" }}>
                  <div>
                    <h3 style={{ margin: 0, fontSize: "16px", display: "flex", alignItems: "center", gap: "8px" }}>
                      <span style={{ width: "24px", height: "24px", borderRadius: "50%", background: "var(--primary)", color: "#fff", display: "inline-grid", placeItems: "center", fontSize: "12px" }}>2</span>
                      Select Failed Course(s) to Re-appear
                    </h3>
                    <p className="muted" style={{ margin: "4px 0 0", fontSize: "13px" }}>
                      Check the box next to each backlog course you wish to attempt in this examination session.
                    </p>
                  </div>

                  <div style={{ display: "flex", gap: "8px" }}>
                    <button type="button" className="secondary" onClick={handleSelectAll} style={{ padding: "6px 12px", fontSize: "13px" }}>
                      Select All
                    </button>
                    <button type="button" className="secondary" onClick={handleDeselectAll} style={{ padding: "6px 12px", fontSize: "13px" }}>
                      Deselect All
                    </button>
                  </div>
                </div>

                <table className="table" style={{ margin: 0 }}>
                  <thead>
                    <tr>
                      <th style={{ width: "40px", textAlign: "center" }}>Select</th>
                      <th>Course Code</th>
                      <th>Course Title</th>
                      <th>Type</th>
                      <th>Credits</th>
                      <th>Failed In</th>
                      <th>Previous Marks</th>
                      <th style={{ textAlign: "center" }}>Grade</th>
                      <th>Subject Fee</th>
                      <th>Status</th>
                    </tr>
                  </thead>
                  <tbody>
                    {failedCourses.map((c) => {
                      const isSelected = selectedOfferings.includes(c.offeringId);
                      return (
                        <tr
                          key={c.offeringId}
                          style={{
                            background: isSelected ? "rgba(22, 163, 74, 0.05)" : "transparent",
                            cursor: "pointer",
                          }}
                          onClick={() => handleToggleOffering(c.offeringId)}
                        >
                          <td style={{ textAlign: "center" }} onClick={(e) => e.stopPropagation()}>
                            <input
                              type="checkbox"
                              checked={isSelected}
                              onChange={() => handleToggleOffering(c.offeringId)}
                              style={{ width: "18px", height: "18px", cursor: "pointer" }}
                            />
                          </td>
                          <td><strong>{c.courseCode}</strong></td>
                          <td>{c.courseTitle}</td>
                          <td><span className="tag">{c.courseType}</span></td>
                          <td><b>{c.credits} cr</b></td>
                          <td>{c.academicYear} ({c.semesterTerm})</td>
                          <td>
                            <span style={{ color: "var(--danger)", fontWeight: 700 }}>
                              {c.totalMarks} / {c.maxMarks}
                            </span>
                          </td>
                          <td style={{ textAlign: "center" }}>
                            <span className="grade-badge grade-F">{c.grade}</span>
                          </td>
                          <td>
                            <b>₹{PER_SUBJECT_FEE}</b>
                          </td>
                          <td>
                            {c.isAlreadySubmitted ? (
                              <Badge tone="warn">FORM SUBMITTED</Badge>
                            ) : (
                              <Badge tone="danger">BACKLOG ACTIVE</Badge>
                            )}
                          </td>
                        </tr>
                      );
                    })}
                  </tbody>
                  <tfoot>
                    <tr style={{ background: "#f8faf7", fontWeight: 700 }}>
                      <td colSpan={4}>Selected Backlog Courses Summary</td>
                      <td>
                        {failedCourses
                          .filter((c) => selectedOfferings.includes(c.offeringId))
                          .reduce((sum, c) => sum + c.credits, 0)}{" "}
                        cr
                      </td>
                      <td colSpan={3} style={{ textAlign: "right" }}>
                        Selected: <b>{selectedCount} course(s)</b>
                      </td>
                      <td colSpan={2}>
                        <b>₹{PER_SUBJECT_FEE * selectedCount}</b> (Subject Fees)
                      </td>
                    </tr>
                  </tfoot>
                </table>
              </div>

              {/* Step 3: Fee Computation & Payment */}
              <div className="card" style={{ padding: "20px" }}>
                <h3 style={{ margin: "0 0 12px", fontSize: "16px", display: "flex", alignItems: "center", gap: "8px" }}>
                  <span style={{ width: "24px", height: "24px", borderRadius: "50%", background: "var(--primary)", color: "#fff", display: "inline-grid", placeItems: "center", fontSize: "12px" }}>3</span>
                  Examination Fee Assessment & Payment Mode
                </h3>

                <div className="form-grid-2" style={{ alignItems: "start" }}>
                  {/* Fee Breakdown Card */}
                  <div style={{ background: "var(--bg)", padding: "16px", borderRadius: "var(--radius-control)", border: "1px solid var(--border)" }}>
                    <h4 style={{ margin: "0 0 10px", fontSize: "14px", textTransform: "uppercase", color: "var(--muted)" }}>
                      Institutional Fee Calculation Breakdown
                    </h4>

                    <div style={{ display: "flex", justifyContent: "space-between", padding: "6px 0", borderBottom: "1px dashed var(--border)", fontSize: "14px" }}>
                      <span>Base Examination Form Processing Fee:</span>
                      <b>₹{BASE_FEE}.00</b>
                    </div>

                    <div style={{ display: "flex", justifyContent: "space-between", padding: "6px 0", borderBottom: "1px dashed var(--border)", fontSize: "14px" }}>
                      <span>Course Re-examination Fee (₹{PER_SUBJECT_FEE} × {selectedCount}):</span>
                      <b>₹{PER_SUBJECT_FEE * selectedCount}.00</b>
                    </div>

                    <div style={{ display: "flex", justifyContent: "space-between", padding: "10px 0 4px", fontSize: "18px", color: "var(--primary)", fontWeight: 800 }}>
                      <span>Total Amount Payable:</span>
                      <span>₹{totalPayableFee}.00</span>
                    </div>

                    <div style={{ fontSize: "12px", color: "var(--muted)", marginTop: "6px" }}>
                      * Fees include question paper setting, evaluation, grade sheet printing, and autonomous university examination cell administrative costs.
                    </div>
                  </div>

                  {/* Payment Method Selector */}
                  <div style={{ display: "flex", flexDirection: "column", gap: "12px" }}>
                    <div>
                      <label htmlFor="payment-mode-select"><strong>Payment Mode *</strong></label>
                      <select
                        id="payment-mode-select"
                        value={paymentMode}
                        onChange={(e) => setPaymentMode(e.target.value)}
                      >
                        <option value="ONLINE">Online UPI / Netbanking / QR (Instant Confirmation)</option>
                        <option value="UPI">UPI Direct (GooglePay / PhonePe / Paytm)</option>
                        <option value="COUNTER_CASH">University Finance Counter Challan (Cash)</option>
                        <option value="CHALLAN">Bank Demand Draft / National Challan</option>
                      </select>
                    </div>

                    <div>
                      <label htmlFor="candidate-remarks"><strong>Candidate Remarks / Subject Specialization (Optional)</strong></label>
                      <input
                        id="candidate-remarks"
                        type="text"
                        placeholder="e.g. 2nd Attempt for Semester IV Analog Comm"
                        value={studentRemarks}
                        onChange={(e) => setStudentRemarks(e.target.value)}
                      />
                    </div>
                  </div>
                </div>
              </div>

              {/* Step 4: Undertaking Declaration & Submission */}
              <div className="card" style={{ padding: "20px" }}>
                <h3 style={{ margin: "0 0 12px", fontSize: "16px", display: "flex", alignItems: "center", gap: "8px" }}>
                  <span style={{ width: "24px", height: "24px", borderRadius: "50%", background: "var(--primary)", color: "#fff", display: "inline-grid", placeItems: "center", fontSize: "12px" }}>4</span>
                  Candidate Declaration & Undertaking
                </h3>

                <div style={{ background: "#f8faf7", padding: "14px 16px", borderRadius: "var(--radius-control)", border: "1px solid var(--border)", fontSize: "13px", lineHeight: "1.6" }}>
                  <label style={{ display: "flex", gap: "10px", alignItems: "flex-start", cursor: "pointer", margin: 0 }}>
                    <input
                      type="checkbox"
                      checked={declarationAccepted}
                      onChange={(e) => setDeclarationAccepted(e.target.checked)}
                      style={{ width: "20px", height: "20px", marginTop: "2px", cursor: "pointer" }}
                      required
                    />
                    <span>
                      <b>I hereby declare that:</b>
                      <br />
                      1. All the particulars stated in this Backlog Examination Form are true, complete, and correct to the best of my knowledge.
                      <br />
                      2. I have completed the prescribed curriculum and coursework attendance in the earlier semester and understand that hall tickets are subject to financial and administrative clearance.
                      <br />
                      3. I agree to abide by the rules, ordinances, and code of conduct of the University Examination Authority. Any malpractice will lead to disciplinary debarment.
                    </span>
                  </label>
                </div>

                <div style={{ display: "flex", justifyContent: "flex-end", alignItems: "center", gap: "16px", marginTop: "18px" }}>
                  <div style={{ textAlign: "right" }}>
                    <div style={{ fontSize: "12px", color: "var(--muted)" }}>Total Due Amount</div>
                    <div style={{ fontSize: "20px", fontWeight: 800, color: "var(--primary)" }}>
                      ₹{totalPayableFee}.00
                    </div>
                  </div>

                  <button
                    type="submit"
                    disabled={submitting || selectedCount === 0 || !declarationAccepted}
                    style={{ padding: "12px 28px", fontSize: "15px", fontWeight: 700 }}
                  >
                    {submitting ? "Submitting Backlog Form..." : "Submit Examination Form"}
                  </button>
                </div>
              </div>
            </form>
          )}
        </div>
      )}

      {/* =========================================================================
          SUB-TAB 2: MY SUBMITTED FORMS & SLIPS (STUDENT VIEW)
          ========================================================================= */}
      {activeSubTab === "candidate_history" && (
        <div className="card" style={{ padding: "0", overflow: "hidden" }}>
          <div style={{ padding: "18px 22px", borderBottom: "1px solid var(--border)", display: "flex", justifyContent: "space-between", alignItems: "center" }}>
            <div>
              <h3 style={{ margin: 0, fontSize: "17px" }}>
                Submitted Backlog Exam Applications • {studentProfile?.full_name || activeStudentId}
              </h3>
              <p className="muted" style={{ margin: "4px 0 0", fontSize: "13px" }}>
                History of official re-examination forms filed for pending courses and hall ticket verification status.
              </p>
            </div>
            <button className="secondary" onClick={() => loadCandidateData(activeStudentId)}>
              Refresh Forms
            </button>
          </div>

          {existingForms.length === 0 ? (
            <div style={{ textAlign: "center", padding: "40px" }}>
              <p className="muted">No backlog exam forms submitted yet for this student.</p>
              <button onClick={() => setActiveSubTab("apply")}>
                Fill New Backlog Exam Form
              </button>
            </div>
          ) : (
            <table className="table" style={{ margin: 0 }}>
              <thead>
                <tr>
                  <th>Form Number</th>
                  <th>Examination Event</th>
                  <th>Subjects</th>
                  <th>Total Fee</th>
                  <th>Payment</th>
                  <th>Submission Date</th>
                  <th>Approval Status</th>
                  <th style={{ textAlign: "right" }}>Action</th>
                </tr>
              </thead>
              <tbody>
                {existingForms.map((form) => (
                  <tr key={form.form_id}>
                    <td><strong>{form.form_no}</strong></td>
                    <td>{form.exam?.exam_name || form.exam_id}</td>
                    <td><b>{form.total_subjects} course(s)</b> ({form.total_credits} cr)</td>
                    <td><b>₹{form.total_fee}</b></td>
                    <td>
                      <StatusBadge status={form.payment_status} />
                    </td>
                    <td>{new Date(form.created_at).toLocaleDateString()}</td>
                    <td>
                      <StatusBadge status={form.status} />
                    </td>
                    <td style={{ textAlign: "right" }}>
                      <button
                        className="secondary"
                        style={{ padding: "5px 12px", fontSize: "13px" }}
                        onClick={() => handleViewSlip(form.form_id)}
                      >
                        🖨️ View & Print Slip
                      </button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
        </div>
      )}

      {/* =========================================================================
          SUB-TAB 3: ALL SUBMITTED FORMS (ADMIN & FACULTY VIEW)
          ========================================================================= */}
      {activeSubTab === "forms_list" && (!isStudent || isAdmin) && (
        <div className="card" style={{ padding: "0", overflow: "hidden" }}>
          {/* Header & Filter Bar */}
          <div style={{ padding: "18px 22px", borderBottom: "1px solid var(--border)", display: "flex", justifyContent: "space-between", alignItems: "center", flexWrap: "wrap", gap: "12px" }}>
            <div>
              <h3 style={{ margin: 0, fontSize: "17px" }}>University Backlog Applications Registry</h3>
              <p className="muted" style={{ margin: "4px 0 0", fontSize: "13px" }}>
                Review and approve re-examination forms submitted by failed students across all programs.
              </p>
            </div>

            <div style={{ display: "flex", gap: "10px", alignItems: "center", flexWrap: "wrap" }}>
              <input
                type="text"
                placeholder="Search candidate or form no..."
                value={searchFilter}
                onChange={(e) => setSearchFilter(e.target.value)}
                style={{ width: "220px", padding: "6px 12px", fontSize: "13px" }}
              />

              <select
                value={statusFilter}
                onChange={(e) => setStatusFilter(e.target.value)}
                style={{ width: "auto", fontSize: "13px", padding: "6px 12px" }}
              >
                <option value="ALL">All Statuses</option>
                <option value="SUBMITTED">SUBMITTED (Pending Review)</option>
                <option value="APPROVED">APPROVED (Registered)</option>
                <option value="UNDER_REVIEW">UNDER REVIEW</option>
                <option value="REJECTED">REJECTED</option>
              </select>

              <button className="secondary" onClick={loadAllForms} style={{ padding: "6px 14px", fontSize: "13px" }}>
                Refresh
              </button>
            </div>
          </div>

          <table className="table" style={{ margin: 0 }}>
            <thead>
              <tr>
                <th>Form No</th>
                <th>Candidate Details</th>
                <th>Target Exam</th>
                <th>Backlog Subjects</th>
                <th>Total Fee</th>
                <th>Payment</th>
                <th>Status</th>
                <th>Filed On</th>
                <th style={{ textAlign: "right" }}>Actions</th>
              </tr>
            </thead>
            <tbody>
              {allForms
                .filter((f) => {
                  if (!searchFilter.trim()) return true;
                  const q = searchFilter.toLowerCase();
                  return (
                    f.form_no?.toLowerCase().includes(q) ||
                    f.student_id?.toLowerCase().includes(q) ||
                    f.student?.full_name?.toLowerCase().includes(q) ||
                    f.student?.enrollment_no?.toLowerCase().includes(q)
                  );
                })
                .map((form) => (
                  <tr key={form.form_id}>
                    <td>
                      <strong>{form.form_no}</strong>
                    </td>
                    <td>
                      <div><b>{form.student?.full_name || form.student_id}</b></div>
                      <small className="muted">{form.student?.enrollment_no} • {form.student_id}</small>
                    </td>
                    <td>
                      <div><b>{form.exam?.exam_name || form.exam_id}</b></div>
                      <small className="muted">{form.exam?.exam_type} Sem {form.exam?.sem_no}</small>
                    </td>
                    <td>
                      <b>{form.total_subjects} course(s)</b>
                      <div style={{ fontSize: "12px", color: "var(--muted)" }}>{form.total_credits} credits</div>
                    </td>
                    <td>
                      <b>₹{form.total_fee}</b>
                      <div style={{ fontSize: "11px", color: "var(--muted)" }}>{form.payment_mode}</div>
                    </td>
                    <td>
                      <StatusBadge status={form.payment_status} />
                    </td>
                    <td>
                      <StatusBadge status={form.status} />
                    </td>
                    <td>
                      {new Date(form.created_at).toLocaleDateString()}
                    </td>
                    <td style={{ textAlign: "right" }}>
                      <div style={{ display: "inline-flex", gap: "6px" }}>
                        <button
                          className="secondary"
                          style={{ padding: "4px 10px", fontSize: "12px" }}
                          onClick={() => handleViewSlip(form.form_id)}
                          title="Print Official Slip"
                        >
                          🖨️ Slip
                        </button>

                        {isAdmin && (
                          <>
                            <button
                              style={{ padding: "4px 10px", fontSize: "12px" }}
                              onClick={() => handleOpenReview(form)}
                              title="Review & Approve"
                            >
                              Review
                            </button>

                            <button
                              className="secondary"
                              style={{ padding: "4px 8px", fontSize: "12px", color: "var(--danger)" }}
                              onClick={() => handleDeleteForm(form.form_id, form.form_no)}
                              title="Delete Form"
                            >
                              🗑️
                            </button>
                          </>
                        )}
                      </div>
                    </td>
                  </tr>
                ))}
              {allForms.length === 0 && (
                <tr>
                  <td colSpan={9} style={{ textAlign: "center", padding: "30px" }} className="muted">
                    No backlog examination forms match the selected filters.
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
      )}

      {/* =========================================================================
          SUB-TAB 4: FAILED STUDENTS REGISTRY (ADMIN & FACULTY VIEW)
          ========================================================================= */}
      {activeSubTab === "registry" && (!isStudent || isAdmin) && (
        <div className="card" style={{ padding: "0", overflow: "hidden" }}>
          <div style={{ padding: "18px 22px", borderBottom: "1px solid var(--border)", display: "flex", justifyContent: "space-between", alignItems: "center", flexWrap: "wrap", gap: "10px" }}>
            <div>
              <h3 style={{ margin: 0, fontSize: "17px" }}>University Failed Students Master Registry</h3>
              <p className="muted" style={{ margin: "4px 0 0", fontSize: "13px" }}>
                Complete roster of candidates with pending course backlogs from previously declared semester results.
              </p>
            </div>
            <span className="tag" style={{ background: "var(--danger-bg)", color: "var(--danger)", fontWeight: 700 }}>
              {failedStudents.length} Students with Active Backlogs
            </span>
          </div>

          <table className="table" style={{ margin: 0 }}>
            <thead>
              <tr>
                <th>Student ID</th>
                <th>Candidate Name</th>
                <th>Enrollment / PRN</th>
                <th>Program</th>
                <th>Backlogs</th>
                <th>Failed Courses Breakdown</th>
                <th>Form Filing Status</th>
                <th style={{ textAlign: "right" }}>Action</th>
              </tr>
            </thead>
            <tbody>
              {failedStudents.map((stud) => (
                <tr key={stud.studentId}>
                  <td><strong>{stud.studentId}</strong></td>
                  <td><b>{stud.fullName}</b></td>
                  <td>{stud.enrollmentNo}</td>
                  <td>{stud.programName} ({stud.programCode})</td>
                  <td>
                    <Badge tone="danger">{stud.failedCoursesCount} Course(s)</Badge>
                  </td>
                  <td>
                    <div style={{ display: "flex", flexDirection: "column", gap: "4px" }}>
                      {stud.failedCourses.map((c) => (
                        <div key={c.resultId} style={{ fontSize: "12px" }}>
                          <b>{c.courseCode}</b>: {c.courseTitle} ({c.totalMarks}/{c.maxMarks} marks, Grade: <span style={{ color: "var(--danger)", fontWeight: 700 }}>F</span>)
                        </div>
                      ))}
                    </div>
                  </td>
                  <td>
                    {stud.latestForm ? (
                      <div>
                        <StatusBadge status={stud.latestForm.status} />
                        <div style={{ fontSize: "11px", color: "var(--muted)", marginTop: "2px" }}>
                          {stud.latestForm.form_no}
                        </div>
                      </div>
                    ) : (
                      <span className="tag" style={{ background: "#fef3c7", color: "#92400e" }}>
                        FORM NOT FILED
                      </span>
                    )}
                  </td>
                  <td style={{ textAlign: "right" }}>
                    <button
                      className="secondary"
                      style={{ padding: "5px 12px", fontSize: "12px", fontWeight: 600 }}
                      onClick={() => {
                        handleSelectStudent(stud.studentId);
                        setActiveSubTab("apply");
                      }}
                    >
                      Fill Form for Candidate →
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      {/* =========================================================================
          OFFICIAL PRINTABLE SLIP MODAL (FORMAL UNIVERSITY APPLICATION SLIP)
          ========================================================================= */}
      {showSlipModal && selectedFormForSlip && (
        <div className="modal-backdrop">
          <div className="modal-card modal-lg" style={{ maxWidth: "850px" }}>
            <div className="modal-header no-print">
              <h2>Official Examination Application Slip</h2>
              <div style={{ display: "flex", gap: "8px" }}>
                <button onClick={handlePrintSlip} style={{ padding: "6px 14px", fontWeight: 700 }}>
                  🖨️ Print / Download PDF
                </button>
                <button className="secondary" onClick={() => setShowSlipModal(false)}>
                  Close
                </button>
              </div>
            </div>

            {/* Official University Form Sheet */}
            <div id="printable-exam-form-sheet" style={{ background: "#fff", color: "#111", padding: "24px", border: "2px solid #111", borderRadius: "4px", fontSize: "12px" }}>
              {/* Header with University Seal & Title */}
              <div style={{ textAlign: "center", borderBottom: "2px solid #111", paddingBottom: "14px", marginBottom: "16px" }}>
                <div style={{ fontSize: "20px", fontWeight: 800, textTransform: "uppercase", letterSpacing: "0.05em", color: "#1d5c4d" }}>
                  UNIVERSITY OF ENGINEERING & TECHNOLOGY
                </div>
                <div style={{ fontSize: "13px", fontWeight: 700, color: "#333", marginTop: "2px" }}>
                  OFFICE OF THE CONTROLLER OF EXAMINATIONS • CENTRAL EXAMINATION CELL
                </div>
                <div style={{ display: "inline-block", background: "#eee", border: "1px solid #777", padding: "4px 14px", fontSize: "13px", fontWeight: 800, marginTop: "8px", textTransform: "uppercase" }}>
                  SUPPLEMENTARY / BACKLOG EXAMINATION APPLICATION FORM
                </div>
                <div style={{ fontSize: "11px", color: "#555", marginTop: "4px" }}>
                  Academic Session {selectedFormForSlip.academic_year} • Candidate Copy & Examination Cell Counterfoil
                </div>
              </div>

              {/* Form Metadata Header Row */}
              <div style={{ display: "flex", justifyContent: "space-between", alignItems: "flex-start", marginBottom: "16px", padding: "8px 12px", background: "#f5f5f5", border: "1px solid #ccc" }}>
                <div>
                  <div>Application Form No: <b style={{ fontSize: "14px", color: "#1d5c4d" }}>{selectedFormForSlip.form_no}</b></div>
                  <div>Submission Date: <b>{new Date(selectedFormForSlip.created_at).toLocaleString()}</b></div>
                  <div>Target Examination: <b>{selectedFormForSlip.exam?.exam_name || selectedFormForSlip.exam_id}</b></div>
                </div>

                <div style={{ textAlign: "right" }}>
                  <div>Application Status: <b style={{ color: selectedFormForSlip.status === "APPROVED" ? "#15803d" : "#b45309" }}>{selectedFormForSlip.status}</b></div>
                  <div>Fee Status: <b style={{ color: "#15803d" }}>{selectedFormForSlip.payment_status} (₹{selectedFormForSlip.total_fee}.00)</b></div>
                  <div>Payment Ref: <b>{selectedFormForSlip.payment_reference || "N/A"}</b></div>
                </div>
              </div>

              {/* Candidate Particulars Table */}
              <table style={{ width: "100%", borderCollapse: "collapse", marginBottom: "16px", fontSize: "12px" }}>
                <tbody>
                  <tr>
                    <td style={{ border: "1px solid #aaa", padding: "6px 10px", width: "25%", background: "#f9f9f9" }}>Candidate Full Name:</td>
                    <td style={{ border: "1px solid #aaa", padding: "6px 10px", width: "45%" }}><b>{selectedFormForSlip.student?.full_name || selectedFormForSlip.student_id}</b></td>
                    <td rowSpan={4} style={{ border: "1px solid #aaa", padding: "6px", width: "30%", textAlign: "center", verticalAlign: "middle", background: "#fcfcfc" }}>
                      <div style={{ border: "1px dashed #777", width: "110px", height: "125px", margin: "0 auto", display: "grid", placeItems: "center", fontSize: "10px", color: "#777" }}>
                        AFFIX CANDIDATE PASSPORT PHOTO HERE
                      </div>
                    </td>
                  </tr>
                  <tr>
                    <td style={{ border: "1px solid #aaa", padding: "6px 10px", background: "#f9f9f9" }}>Student Identity ID:</td>
                    <td style={{ border: "1px solid #aaa", padding: "6px 10px" }}><b>{selectedFormForSlip.student_id}</b></td>
                  </tr>
                  <tr>
                    <td style={{ border: "1px solid #aaa", padding: "6px 10px", background: "#f9f9f9" }}>Enrollment / PRN No:</td>
                    <td style={{ border: "1px solid #aaa", padding: "6px 10px" }}><b>{selectedFormForSlip.student?.enrollment_no || "--"}</b></td>
                  </tr>
                  <tr>
                    <td style={{ border: "1px solid #aaa", padding: "6px 10px", background: "#f9f9f9" }}>Degree & Department:</td>
                    <td style={{ border: "1px solid #aaa", padding: "6px 10px" }}>
                      <b>{selectedFormForSlip.student?.program?.program_name || "Engineering"} ({selectedFormForSlip.student?.program?.program_code || "ENG"})</b>
                    </td>
                  </tr>
                </tbody>
              </table>

              {/* Registered Backlog Papers Table */}
              <div style={{ fontWeight: 700, fontSize: "13px", marginBottom: "6px", textTransform: "uppercase" }}>
                Course Papers Enrolled for Examination:
              </div>
              <table style={{ width: "100%", borderCollapse: "collapse", marginBottom: "16px", fontSize: "12px" }}>
                <thead>
                  <tr style={{ background: "#eaeaea" }}>
                    <th style={{ border: "1px solid #888", padding: "6px 8px", textAlign: "center", width: "35px" }}>Sr.</th>
                    <th style={{ border: "1px solid #888", padding: "6px 8px", textAlign: "left" }}>Course Code</th>
                    <th style={{ border: "1px solid #888", padding: "6px 8px", textAlign: "left" }}>Course Title</th>
                    <th style={{ border: "1px solid #888", padding: "6px 8px", textAlign: "center", width: "60px" }}>Credits</th>
                    <th style={{ border: "1px solid #888", padding: "6px 8px", textAlign: "center", width: "80px" }}>Attempt</th>
                    <th style={{ border: "1px solid #888", padding: "6px 8px", textAlign: "center", width: "80px" }}>Prev. Marks</th>
                    <th style={{ border: "1px solid #888", padding: "6px 8px", textAlign: "right", width: "90px" }}>Course Fee</th>
                  </tr>
                </thead>
                <tbody>
                  {(selectedFormForSlip.items ?? []).map((item, idx) => (
                    <tr key={item.item_id}>
                      <td style={{ border: "1px solid #888", padding: "6px 8px", textAlign: "center" }}>{idx + 1}</td>
                      <td style={{ border: "1px solid #888", padding: "6px 8px" }}><b>{item.course_code}</b></td>
                      <td style={{ border: "1px solid #888", padding: "6px 8px" }}>{item.course_title}</td>
                      <td style={{ border: "1px solid #888", padding: "6px 8px", textAlign: "center" }}>{item.credits}</td>
                      <td style={{ border: "1px solid #888", padding: "6px 8px", textAlign: "center" }}>Attempt {item.attempt_no}</td>
                      <td style={{ border: "1px solid #888", padding: "6px 8px", textAlign: "center" }}>
                        <span style={{ color: "#b91c1c", fontWeight: 700 }}>{item.previous_marks} ({item.previous_grade})</span>
                      </td>
                      <td style={{ border: "1px solid #888", padding: "6px 8px", textAlign: "right" }}>₹{item.fee_amount}.00</td>
                    </tr>
                  ))}
                </tbody>
                <tfoot>
                  <tr style={{ background: "#f5f5f5", fontWeight: 700 }}>
                    <td colSpan={3} style={{ border: "1px solid #888", padding: "6px 8px" }}>
                      Institutional Base Registration Fee:
                    </td>
                    <td colSpan={3} style={{ border: "1px solid #888", padding: "6px 8px", textAlign: "right" }}>
                      ₹{selectedFormForSlip.base_fee}.00
                    </td>
                    <td style={{ border: "1px solid #888", padding: "6px 8px", textAlign: "right" }}>
                      ₹{selectedFormForSlip.base_fee}.00
                    </td>
                  </tr>
                  <tr style={{ background: "#e5e7eb", fontWeight: 800, fontSize: "13px" }}>
                    <td colSpan={3} style={{ border: "1px solid #888", padding: "8px" }}>
                      Total Amount Paid ({selectedFormForSlip.total_subjects} Papers):
                    </td>
                    <td style={{ border: "1px solid #888", padding: "8px", textAlign: "center" }}>
                      {selectedFormForSlip.total_credits} cr
                    </td>
                    <td colSpan={2} style={{ border: "1px solid #888", padding: "8px", textAlign: "right" }}>
                      Payment: {selectedFormForSlip.payment_mode}
                    </td>
                    <td style={{ border: "1px solid #888", padding: "8px", textAlign: "right", color: "#1d5c4d" }}>
                      ₹{selectedFormForSlip.total_fee}.00
                    </td>
                  </tr>
                </tfoot>
              </table>

              {/* Declaration Undertaking */}
              <div style={{ fontSize: "11px", color: "#444", marginBottom: "28px", border: "1px solid #ccc", padding: "8px 12px", background: "#fafafa" }}>
                <b>Declaration by Candidate:</b> I hereby solemnly affirm that I have read the university examination regulations and that the information furnished by me in this application is correct. I undertake that if any statement is found incorrect, my candidature shall stand automatically cancelled.
              </div>

              {/* Signatures & Seal Block */}
              <div style={{ display: "flex", justifyContent: "space-between", alignItems: "flex-end", marginTop: "40px", padding: "0 20px", textAlign: "center" }}>
                <div>
                  <div style={{ borderBottom: "1px solid #222", width: "170px", marginBottom: "6px" }}></div>
                  <div style={{ fontSize: "11px", fontWeight: 700 }}>Candidate's Signature</div>
                </div>

                <div>
                  <div style={{ borderBottom: "1px solid #222", width: "170px", marginBottom: "6px" }}></div>
                  <div style={{ fontSize: "11px", fontWeight: 700 }}>HOD / Academic Dean Endorsement</div>
                </div>

                <div>
                  <div style={{ borderBottom: "1px solid #222", width: "190px", marginBottom: "6px" }}></div>
                  <div style={{ fontSize: "11px", fontWeight: 700 }}>Controller of Examinations (CoE)</div>
                  <div style={{ fontSize: "9px", color: "#777" }}>Official Institutional Seal</div>
                </div>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* =========================================================================
          ADMIN REVIEW & APPROVAL MODAL
          ========================================================================= */}
      {showReviewModal && selectedFormForReview && (
        <div className="modal-backdrop">
          <div className="modal-card" style={{ maxWidth: "600px" }}>
            <div className="modal-header">
              <h2>Review Backlog Examination Form</h2>
              <button className="secondary" onClick={() => setShowReviewModal(false)}>✕</button>
            </div>

            <div style={{ display: "flex", flexDirection: "column", gap: "16px" }}>
              <div style={{ background: "var(--bg)", padding: "12px", borderRadius: "var(--radius-control)" }}>
                <div>Form No: <b>{selectedFormForReview.form_no}</b></div>
                <div>Candidate: <b>{selectedFormForReview.student?.full_name}</b> ({selectedFormForReview.student_id})</div>
                <div>Target Exam: <b>{selectedFormForReview.exam?.exam_name || selectedFormForReview.exam_id}</b></div>
                <div>Enrolled Courses: <b>{selectedFormForReview.total_subjects} course(s)</b> • Fee: <b>₹{selectedFormForReview.total_fee}</b></div>
              </div>

              <div>
                <label><strong>Application Status *</strong></label>
                <select
                  value={reviewStatus}
                  onChange={(e) => setReviewStatus(e.target.value as any)}
                >
                  <option value="APPROVED">APPROVED (Auto-register candidate in exam schedules)</option>
                  <option value="UNDER_REVIEW">UNDER REVIEW (Pending document/eligibility check)</option>
                  <option value="REJECTED">REJECTED (Candidate ineligible / fee dishonored)</option>
                </select>
              </div>

              <div>
                <label><strong>Fee Clearance Status *</strong></label>
                <select
                  value={reviewPaymentStatus}
                  onChange={(e) => setReviewPaymentStatus(e.target.value as any)}
                >
                  <option value="PAID">PAID (Fees cleared at counter / online)</option>
                  <option value="PENDING">PENDING (Challan awaiting verification)</option>
                </select>
              </div>

              <div>
                <label><strong>Reviewer Remarks / Endorsement Note</strong></label>
                <textarea
                  rows={3}
                  value={reviewRemarks}
                  onChange={(e) => setReviewRemarks(e.target.value)}
                  placeholder="e.g. Verified eligibility and fee receipt. Approved for Hall Ticket issuance."
                />
              </div>

              <div className="modal-actions">
                <button className="secondary" onClick={() => setShowReviewModal(false)}>
                  Cancel
                </button>
                <button onClick={handleSubmitReview}>
                  Save Review Decision
                </button>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
