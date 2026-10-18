import { useEffect, useState } from "react";
import { Badge, StatusBadge } from "../../components/Badge";
import { api } from "../../lib/api";

interface PreviewData {
  exam: {
    exam_id: string;
    exam_name: string;
    exam_type: string;
    status: string;
    sem_no: number;
  };
  totalStudents: number;
  passedCount: number;
  failedCount: number;
  totalSchedules: number;
  approvedSchedules: number;
  unapprovedOfferings: Array<{ offeringId: number; courseCode: string }>;
  readyToPublish: boolean;
  preview: Array<{
    studentId: string;
    fullName: string;
    totalMarks: number;
    maxMarks: number;
    percentage: number;
    grade: string;
    status: string;
    courses: Array<{
      courseCode: string;
      obtained: number;
      maxMarks: number;
      grade: string;
      isAbsent: boolean;
    }>;
  }>;
}

interface PublishedResultItem {
  result_id: number;
  student_id: string;
  offering_id: number;
  total_marks: number;
  max_marks: number;
  percentage: number;
  grade: string;
  published_on: string;
  student?: { full_name: string; enrollment_no: string };
  course_offering?: { course_code: string; course?: { course_title: string; credits: number } };
}

interface ResultManagementProps {
  isAdmin: boolean;
}

export function ResultManagement({ isAdmin }: ResultManagementProps) {
  const [exams, setExams] = useState<Array<{ exam_id: string; exam_name: string; status: string }>>([]);
  const [selectedExamId, setSelectedExamId] = useState<string>("");
  const [examStatus, setExamStatus] = useState<string>("");

  // Preview state (before publishing)
  const [preview, setPreview] = useState<PreviewData | null>(null);

  // Published results state
  const [publishedResults, setPublishedResults] = useState<PublishedResultItem[]>([]);

  const [loading, setLoading] = useState(false);
  const [publishing, setPublishing] = useState(false);
  const [error, setError] = useState("");
  const [success, setSuccess] = useState("");
  const [search, setSearch] = useState("");
  const [filterGrade, setFilterGrade] = useState("");

  const [showConfirmModal, setShowConfirmModal] = useState(false);

  // Load exams
  useEffect(() => {
    api<{ items: Array<{ exam_id: string; exam_name: string; status: string }> }>("/exams")
      .then((res) => {
        setExams(res.items || []);
        if (res.items?.length > 0) {
          const published = res.items.find((e) => e.status === "RESULTS_PUBLISHED") || res.items[0];
          setSelectedExamId(published.exam_id);
          setExamStatus(published.status);
        }
      })
      .catch((err: Error) => setError(err.message));
  }, []);

  const loadExamResults = () => {
    if (!selectedExamId) return;
    setLoading(true);
    setError("");
    setSuccess("");

    const current = exams.find((e) => e.exam_id === selectedExamId);
    const isPub = current?.status === "RESULTS_PUBLISHED";
    setExamStatus(current?.status || "");

    if (isPub) {
      api<{ results: PublishedResultItem[] }>(`/exams/${selectedExamId}/results`)
        .then((res) => {
          setPublishedResults(res.results || []);
          setPreview(null);
        })
        .catch((err: Error) => setError(err.message))
        .finally(() => setLoading(false));
    } else {
      api<PreviewData>(`/exams/${selectedExamId}/results/preview`)
        .then((res) => {
          setPreview(res);
          setPublishedResults([]);
        })
        .catch((err: Error) => setError(err.message))
        .finally(() => setLoading(false));
    }
  };

  useEffect(() => {
    loadExamResults();
  }, [selectedExamId]);

  const handlePublish = async () => {
    if (!selectedExamId) return;
    setPublishing(true);
    setError("");

    try {
      const res = await api<{ message: string; summary: any }>(`/exams/${selectedExamId}/results/publish`, {
        method: "POST",
      });

      setSuccess(res.message);
      setShowConfirmModal(false);

      // Refresh exams list status
      const updatedExams = await api<{ items: Array<{ exam_id: string; exam_name: string; status: string }> }>("/exams");
      setExams(updatedExams.items || []);
      loadExamResults();
    } catch (err) {
      setError((err as Error).message);
    } finally {
      setPublishing(false);
    }
  };

  const filteredPublished = publishedResults.filter((r) => {
    const q = search.toLowerCase();
    const matchesSearch =
      !q ||
      r.student_id.toLowerCase().includes(q) ||
      r.student?.full_name.toLowerCase().includes(q) ||
      r.course_offering?.course_code.toLowerCase().includes(q) ||
      r.course_offering?.course?.course_title.toLowerCase().includes(q);

    const matchesGrade = !filterGrade || r.grade === filterGrade;
    return matchesSearch && matchesGrade;
  });

  return (
    <div style={{ display: "flex", flexDirection: "column", gap: "20px" }}>
      {/* Selection Card */}
      <div className="card" style={{ display: "flex", alignItems: "center", justifyContent: "space-between", flexWrap: "wrap", gap: "16px" }}>
        <div style={{ display: "flex", alignItems: "center", gap: "14px", flexWrap: "wrap" }}>
          <label style={{ minWidth: "300px", margin: 0 }}>
            Select Examination Event
            <select
              value={selectedExamId}
              onChange={(e) => setSelectedExamId(e.target.value)}
            >
              {exams.map((ex) => (
                <option key={ex.exam_id} value={ex.exam_id}>
                  {ex.exam_id} - {ex.exam_name} [{ex.status}]
                </option>
              ))}
            </select>
          </label>

          <StatusBadge status={examStatus || "SCHEDULED"} />
        </div>

        {isAdmin && examStatus !== "RESULTS_PUBLISHED" && preview && (
          <button
            disabled={!preview.readyToPublish || publishing}
            onClick={() => setShowConfirmModal(true)}
            style={{ background: "var(--success)", borderColor: "var(--success)" }}
          >
            {publishing ? "Publishing..." : "🚀 Publish Examination Results"}
          </button>
        )}
      </div>

      {error && <div className="form-alert danger">{error}</div>}
      {success && <div className="form-alert success">{success}</div>}

      {/* STATE 1: RESULTS ALREADY PUBLISHED */}
      {examStatus === "RESULTS_PUBLISHED" && (
        <>
          <div className="result-card-banner">
            <div style={{ display: "flex", justifyContent: "space-between", alignItems: "flex-start", flexWrap: "wrap", gap: "12px" }}>
              <div>
                <span className="badge success" style={{ marginBottom: "8px" }}>OFFICIALLY PUBLISHED</span>
                <h2 style={{ color: "#fff", margin: "4px 0" }}>
                  Examination Results Declared ({selectedExamId})
                </h2>
                <p style={{ color: "#dcebe4", margin: 0, fontSize: "14px" }}>
                  These course results are final, grade points are computed, and student transcripts are updated.
                </p>
              </div>
              <button className="secondary" onClick={() => window.print()} style={{ color: "var(--text)" }}>
                🖨️ Print Result Summary
              </button>
            </div>

            <div className="result-stat-row">
              <div className="result-stat-box">
                <small>Total Grade Records</small>
                <strong>{publishedResults.length}</strong>
              </div>
              <div className="result-stat-box">
                <small>Passing Grades (O to P)</small>
                <strong>{publishedResults.filter((r) => r.grade !== "F").length}</strong>
              </div>
              <div className="result-stat-box">
                <small>Failing Grades (F)</small>
                <strong style={{ color: "#fca5a5" }}>{publishedResults.filter((r) => r.grade === "F").length}</strong>
              </div>
              <div className="result-stat-box">
                <small>Pass Percentage</small>
                <strong>
                  {publishedResults.length > 0
                    ? ((publishedResults.filter((r) => r.grade !== "F").length / publishedResults.length) * 100).toFixed(1)
                    : 0}%
                </strong>
              </div>
            </div>
          </div>

          {/* Filter Bar */}
          <div className="card no-print" style={{ display: "flex", alignItems: "center", gap: "12px", flexWrap: "wrap" }}>
            <input
              type="search"
              placeholder="Search student or course..."
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              style={{ width: "260px" }}
            />

            <select
              value={filterGrade}
              onChange={(e) => setFilterGrade(e.target.value)}
              style={{ width: "140px" }}
            >
              <option value="">All Grades</option>
              <option value="O">O (Outstanding)</option>
              <option value="A+">A+ (Excellent)</option>
              <option value="A">A (Very Good)</option>
              <option value="B+">B+ (Good)</option>
              <option value="B">B (Above Avg)</option>
              <option value="C">C (Average)</option>
              <option value="P">P (Pass)</option>
              <option value="F">F (Fail)</option>
            </select>

            <span className="muted" style={{ marginLeft: "auto", fontSize: "13px" }}>
              Showing {filteredPublished.length} of {publishedResults.length} records
            </span>
          </div>

          {/* Published Results Table */}
          <div className="table-wrap">
            <table className="table">
              <thead>
                <tr>
                  <th>Student ID</th>
                  <th>Enrollment No</th>
                  <th>Student Full Name</th>
                  <th>Course Code & Title</th>
                  <th>Total Marks</th>
                  <th>Percentage</th>
                  <th>Grade</th>
                  <th>Published On</th>
                </tr>
              </thead>
              <tbody>
                {loading && (
                  <tr>
                    <td colSpan={8} className="muted" style={{ textAlign: "center", padding: "30px" }}>
                      Loading published records...
                    </td>
                  </tr>
                )}
                {!loading && filteredPublished.length === 0 && (
                  <tr>
                    <td colSpan={8} className="muted" style={{ textAlign: "center", padding: "30px" }}>
                      No published results match your criteria.
                    </td>
                  </tr>
                )}
                {!loading &&
                  filteredPublished.map((r) => (
                    <tr key={r.result_id}>
                      <td><strong>{r.student_id}</strong></td>
                      <td>{r.student?.enrollment_no || r.student_id}</td>
                      <td>{r.student?.full_name}</td>
                      <td>
                        <b>{r.course_offering?.course_code}</b>
                        <div className="muted" style={{ fontSize: "12px" }}>
                          {r.course_offering?.course?.course_title}
                        </div>
                      </td>
                      <td>
                        <b>{r.total_marks}</b> / {r.max_marks}
                      </td>
                      <td>{r.percentage}%</td>
                      <td>
                        <span className={`grade-badge grade-${r.grade.replace("+", "-plus")}`}>
                          {r.grade}
                        </span>
                      </td>
                      <td className="muted" style={{ fontSize: "12px" }}>
                        {r.published_on ? new Date(r.published_on).toLocaleDateString() : "--"}
                      </td>
                    </tr>
                  ))}
              </tbody>
            </table>
          </div>
        </>
      )}

      {/* STATE 2: RESULTS PENDING PUBLICATION / PREVIEW */}
      {examStatus !== "RESULTS_PUBLISHED" && preview && (
        <>
          {/* Readiness Verification Strip */}
          <div className="card">
            <h3 style={{ margin: "0 0 12px", fontSize: "16px" }}>Publication Readiness Checklist</h3>
            <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fit, minmax(220px, 1fr))", gap: "14px" }}>
              <div style={{ padding: "14px", borderRadius: "var(--radius-control)", background: "var(--bg)" }}>
                <span className="muted" style={{ fontSize: "12px" }}>TOTAL EVALUATED STUDENTS</span>
                <div style={{ fontSize: "24px", fontWeight: 700, color: "var(--primary)" }}>
                  {preview.totalStudents}
                </div>
              </div>

              <div style={{ padding: "14px", borderRadius: "var(--radius-control)", background: "var(--bg)" }}>
                <span className="muted" style={{ fontSize: "12px" }}>APPROVED COURSE PAPERS</span>
                <div style={{ fontSize: "24px", fontWeight: 700 }}>
                  {preview.approvedSchedules} / {preview.totalSchedules}
                </div>
              </div>

              <div style={{ padding: "14px", borderRadius: "var(--radius-control)", background: "var(--bg)" }}>
                <span className="muted" style={{ fontSize: "12px" }}>PROJECTED PASS / FAIL</span>
                <div style={{ fontSize: "20px", fontWeight: 700 }}>
                  <span style={{ color: "var(--success)" }}>{preview.passedCount} Pass</span> •{" "}
                  <span style={{ color: "var(--danger)" }}>{preview.failedCount} Fail</span>
                </div>
              </div>

              <div style={{ padding: "14px", borderRadius: "var(--radius-control)", background: preview.readyToPublish ? "var(--success-bg)" : "var(--warn-bg)" }}>
                <span style={{ fontSize: "12px", fontWeight: 700, color: preview.readyToPublish ? "var(--success)" : "var(--warn)" }}>
                  {preview.readyToPublish ? "✓ READY TO PUBLISH" : "⚠️ APPROVAL PENDING"}
                </span>
                <div style={{ fontSize: "13px", marginTop: "4px" }}>
                  {preview.readyToPublish
                    ? "All scheduled course marks are verified and approved."
                    : `${preview.unapprovedOfferings.length} papers require marks approval before publishing.`}
                </div>
              </div>
            </div>

            {preview.unapprovedOfferings.length > 0 && (
              <div style={{ marginTop: "16px", padding: "10px 14px", background: "var(--warn-bg)", borderRadius: "8px", fontSize: "13px", color: "var(--warn)" }}>
                <b>Pending Approval Course Papers:</b> {preview.unapprovedOfferings.map((u) => u.courseCode).join(", ")}.
                Visit the <b>Marks Entry & Approval</b> tab to review and approve these submissions.
              </div>
            )}
          </div>

          {/* Preliminary Calculated Results Table */}
          <h3 style={{ margin: "10px 0 4px", fontSize: "16px" }}>
            Preliminary Calculated Results Preview ({preview.preview.length} of {preview.totalStudents} students)
          </h3>
          <div className="table-wrap">
            <table className="table">
              <thead>
                <tr>
                  <th>Student ID</th>
                  <th>Student Name</th>
                  <th>Total Obtained</th>
                  <th>Max Marks</th>
                  <th>Percentage</th>
                  <th>Tentative Grade</th>
                  <th>Status</th>
                </tr>
              </thead>
              <tbody>
                {preview.preview.map((p) => (
                  <tr key={p.studentId}>
                    <td><strong>{p.studentId}</strong></td>
                    <td>{p.fullName}</td>
                    <td><b>{p.totalMarks}</b></td>
                    <td>{p.maxMarks}</td>
                    <td>{p.percentage}%</td>
                    <td>
                      <span className={`grade-badge grade-${p.grade.replace("+", "-plus")}`}>
                        {p.grade}
                      </span>
                    </td>
                    <td>
                      <Badge tone={p.status === "PASS" ? "success" : "danger"}>
                        {p.status}
                      </Badge>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </>
      )}

      {/* CONFIRM PUBLICATION MODAL */}
      {showConfirmModal && (
        <div className="modal-backdrop" onClick={() => setShowConfirmModal(false)}>
          <div className="modal-card" onClick={(e) => e.stopPropagation()}>
            <div className="modal-header">
              <h2>Confirm Official Result Publication</h2>
              <button className="icon" onClick={() => setShowConfirmModal(false)}>✕</button>
            </div>
            <div className="form-alert warn">
              <strong>Notice:</strong> Publishing results will generate final grade records in the database, calculate student credit weightings and SGPA, declare official results to students, and lock the marks from further modifications.
            </div>
            <p>
              Are you sure you want to declare and publish the results for <b>{selectedExamId}</b>?
            </p>
            <div className="modal-actions">
              <button className="secondary" onClick={() => setShowConfirmModal(false)}>
                Cancel
              </button>
              <button
                style={{ background: "var(--success)", borderColor: "var(--success)" }}
                onClick={handlePublish}
                disabled={publishing}
              >
                {publishing ? "Publishing Results..." : "Confirm & Publish Now"}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
