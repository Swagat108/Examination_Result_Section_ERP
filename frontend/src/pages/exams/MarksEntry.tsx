import { useEffect, useState } from "react";
import { Badge, StatusBadge } from "../../components/Badge";
import { api } from "../../lib/api";

interface OfferingSummary {
  scheduleId: number;
  examId: string;
  offeringId: number;
  courseCode: string;
  courseTitle: string;
  credits: number;
  facultyId?: string;
  facultyName?: string;
  examDate: string;
  maxMarks: number;
  passingMarks: number;
  marksEnteredCount: number;
  submissionStatus: "DRAFT" | "SUBMITTED" | "UNDER_REVIEW" | "APPROVED" | "REJECTED";
  submittedAt?: string;
  reviewedAt?: string;
  rejectionReason?: string;
}

interface StudentMarkRow {
  studentId: string;
  enrollmentNo: string;
  fullName: string;
  marksObtained: number | null;
  isAbsent: boolean;
}

interface MarksEntryProps {
  isAdmin: boolean;
  preselectedExamId?: string;
}

export function MarksEntry({ isAdmin, preselectedExamId }: MarksEntryProps) {
  const [exams, setExams] = useState<Array<{ exam_id: string; exam_name: string; sem_no: number }>>([]);
  const [selectedExamId, setSelectedExamId] = useState<string>(preselectedExamId || "");
  const [offerings, setOfferings] = useState<OfferingSummary[]>([]);
  const [selectedOfferingId, setSelectedOfferingId] = useState<number>(0);

  // Student marksheet
  const [students, setStudents] = useState<StudentMarkRow[]>([]);
  const [schedule, setSchedule] = useState<any>(null);
  const [submission, setSubmission] = useState<{ status: string; rejection_reason?: string } | null>(null);

  const [loading, setLoading] = useState(false);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState("");
  const [success, setSuccess] = useState("");

  // Admin rejection modal
  const [showRejectModal, setShowRejectModal] = useState(false);
  const [rejectionReason, setRejectionReason] = useState("");

  // Load exams list
  useEffect(() => {
    api<{ items: Array<{ exam_id: string; exam_name: string; sem_no: number }> }>("/exams")
      .then((res) => {
        setExams(res.items || []);
        if (!selectedExamId && res.items?.length > 0) {
          setSelectedExamId(res.items[0].exam_id);
        }
      })
      .catch((err: Error) => setError(err.message));
  }, []);

  // Load offerings when exam changes
  useEffect(() => {
    if (!selectedExamId) return;
    setLoading(true);
    setSelectedOfferingId(0);
    setStudents([]);
    setSchedule(null);
    setSubmission(null);

    api<{ items: OfferingSummary[] }>(`/exams/${selectedExamId}/offerings`)
      .then((res) => {
        setOfferings(res.items || []);
        if (res.items?.length > 0) {
          setSelectedOfferingId(res.items[0].offeringId);
        }
      })
      .catch((err: Error) => setError(err.message))
      .finally(() => setLoading(false));
  }, [selectedExamId]);

  // Load marks when offering changes
  useEffect(() => {
    if (!selectedExamId || !selectedOfferingId) return;
    setLoading(true);
    setError("");
    setSuccess("");

    api<{
      schedule: any;
      submission: { status: string; rejection_reason?: string };
      students: StudentMarkRow[];
    }>(`/exams/${selectedExamId}/offerings/${selectedOfferingId}/marks`)
      .then((res) => {
        setSchedule(res.schedule);
        setSubmission(res.submission);
        setStudents(res.students || []);
      })
      .catch((err: Error) => setError(err.message))
      .finally(() => setLoading(false));
  }, [selectedExamId, selectedOfferingId]);

  const updateMark = (studentId: string, val: string) => {
    setStudents((prev) =>
      prev.map((s) => {
        if (s.studentId !== studentId) return s;
        if (val === "") return { ...s, marksObtained: null };
        const num = parseFloat(val);
        return { ...s, marksObtained: isNaN(num) ? null : num };
      }),
    );
  };

  const toggleAbsent = (studentId: string) => {
    setStudents((prev) =>
      prev.map((s) => {
        if (s.studentId !== studentId) return s;
        const nextAbsent = !s.isAbsent;
        return {
          ...s,
          isAbsent: nextAbsent,
          marksObtained: nextAbsent ? null : s.marksObtained,
        };
      }),
    );
  };

  const handleSave = async (action: "SAVE_DRAFT" | "SUBMIT") => {
    if (!selectedExamId || !selectedOfferingId) return;
    setSaving(true);
    setError("");
    setSuccess("");

    // Validate marks
    const max = schedule?.max_marks ?? 100;
    for (const s of students) {
      if (!s.isAbsent && s.marksObtained !== null) {
        if (s.marksObtained < 0 || s.marksObtained > max) {
          setError(`Marks for student ${s.fullName} must be between 0 and ${max}`);
          setSaving(false);
          return;
        }
      }
    }

    try {
      const res = await api<{ message: string; status: string }>(
        `/exams/${selectedExamId}/offerings/${selectedOfferingId}/marks`,
        {
          method: "POST",
          body: {
            action,
            marks: students.map((s) => ({
              studentId: s.studentId,
              marksObtained: s.marksObtained,
              isAbsent: s.isAbsent,
            })),
          },
        },
      );

      setSuccess(res.message);
      setSubmission((prev) => ({ ...(prev || {}), status: res.status }));

      // Refresh offerings list summary
      const offRes = await api<{ items: OfferingSummary[] }>(`/exams/${selectedExamId}/offerings`);
      setOfferings(offRes.items || []);
    } catch (err) {
      setError((err as Error).message);
    } finally {
      setSaving(false);
    }
  };

  const handleAdminReview = async (action: "UNDER_REVIEW" | "APPROVE" | "REJECT") => {
    if (!selectedExamId || !selectedOfferingId) return;
    if (action === "REJECT" && !rejectionReason.trim()) {
      setError("Please provide a rejection reason when sending marks back for correction");
      return;
    }

    setSaving(true);
    setError("");

    try {
      const res = await api<{ message: string; status: string }>(
        `/exams/${selectedExamId}/offerings/${selectedOfferingId}/review`,
        {
          method: "POST",
          body: {
            action,
            rejectionReason: action === "REJECT" ? rejectionReason : undefined,
          },
        },
      );

      setSuccess(res.message);
      setSubmission((prev) => ({ ...(prev || {}), status: res.status }));
      setShowRejectModal(false);
      setRejectionReason("");

      // Refresh offerings list summary
      const offRes = await api<{ items: OfferingSummary[] }>(`/exams/${selectedExamId}/offerings`);
      setOfferings(offRes.items || []);
    } catch (err) {
      setError((err as Error).message);
    } finally {
      setSaving(false);
    }
  };

  const currentOffering = offerings.find((o) => o.offeringId === selectedOfferingId);
  const isLocked = submission?.status === "APPROVED" || (!isAdmin && (submission?.status === "SUBMITTED" || submission?.status === "UNDER_REVIEW"));

  return (
    <div style={{ display: "flex", flexDirection: "column", gap: "20px" }}>
      {/* Selector Card */}
      <div className="card" style={{ display: "flex", flexWrap: "wrap", gap: "16px", alignItems: "flex-end" }}>
        <label style={{ minWidth: "260px", margin: 0 }}>
          Select Examination
          <select
            value={selectedExamId}
            onChange={(e) => setSelectedExamId(e.target.value)}
          >
            {exams.map((ex) => (
              <option key={ex.exam_id} value={ex.exam_id}>
                {ex.exam_id} - {ex.exam_name} (Sem {ex.sem_no})
              </option>
            ))}
          </select>
        </label>

        <label style={{ minWidth: "320px", flex: 1, margin: 0 }}>
          Select Course Paper / Offering
          <select
            value={selectedOfferingId}
            onChange={(e) => setSelectedOfferingId(Number(e.target.value))}
            disabled={offerings.length === 0}
          >
            {offerings.length === 0 && <option value={0}>No course papers found</option>}
            {offerings.map((o) => (
              <option key={o.offeringId} value={o.offeringId}>
                {o.courseCode} - {o.courseTitle} ({o.marksEnteredCount} marks entered) • [{o.submissionStatus}]
              </option>
            ))}
          </select>
        </label>
      </div>

      {error && <div className="form-alert danger">{error}</div>}
      {success && <div className="form-alert success">{success}</div>}

      {/* Offering Meta & Status Banner */}
      {currentOffering && (
        <div
          className="card"
          style={{
            display: "flex",
            justifyContent: "space-between",
            alignItems: "center",
            flexWrap: "wrap",
            gap: "16px",
            background: "var(--surface)",
            borderLeft: "5px solid var(--primary)",
          }}
        >
          <div>
            <div style={{ display: "flex", alignItems: "center", gap: "10px", marginBottom: "6px" }}>
              <h2 style={{ margin: 0, fontSize: "18px" }}>
                {currentOffering.courseCode}: {currentOffering.courseTitle}
              </h2>
              <span className="tag">{currentOffering.credits} Credits</span>
              <StatusBadge status={currentOffering.submissionStatus} />
            </div>
            <div className="muted" style={{ fontSize: "13px" }}>
              Faculty Instructor: <b>{currentOffering.facultyName || "Unassigned"}</b> • Max Marks: <b>{currentOffering.maxMarks}</b> • Passing Marks: <b>{currentOffering.passingMarks}</b>
            </div>
            {submission?.rejection_reason && (
              <div style={{ marginTop: "10px", padding: "8px 12px", background: "var(--danger-bg)", color: "var(--danger)", borderRadius: "8px", fontSize: "13px" }}>
                <b>Rejection Reason from Administration:</b> {submission.rejection_reason}
              </div>
            )}
          </div>

          {/* Action Workflow Buttons */}
          <div style={{ display: "flex", gap: "10px", flexWrap: "wrap" }}>
            {!isLocked && (
              <>
                <button
                  className="secondary"
                  onClick={() => handleSave("SAVE_DRAFT")}
                  disabled={saving}
                >
                  {saving ? "Saving..." : "Save Draft"}
                </button>
                <button
                  onClick={() => handleSave("SUBMIT")}
                  disabled={saving}
                >
                  Submit for Review
                </button>
              </>
            )}

            {isLocked && !isAdmin && (
              <span className="badge warn" style={{ padding: "8px 14px", fontSize: "13px" }}>
                🔒 Submitted for Review (Read-only)
              </span>
            )}

            {/* Admin Verification Controls */}
            {isAdmin && (
              <div style={{ display: "flex", gap: "8px", borderLeft: "2px solid var(--border)", paddingLeft: "12px" }}>
                {submission?.status !== "APPROVED" && (
                  <button
                    style={{ background: "var(--success)", borderColor: "var(--success)" }}
                    onClick={() => handleAdminReview("APPROVE")}
                    disabled={saving}
                  >
                    ✓ Approve Marks
                  </button>
                )}
                {submission?.status !== "REJECTED" && (
                  <button
                    className="secondary"
                    style={{ color: "var(--danger)", borderColor: "var(--danger)" }}
                    onClick={() => setShowRejectModal(true)}
                    disabled={saving}
                  >
                    ✕ Return for Correction
                  </button>
                )}
                {submission?.status === "SUBMITTED" && (
                  <button
                    className="secondary"
                    onClick={() => handleAdminReview("UNDER_REVIEW")}
                    disabled={saving}
                  >
                    Mark Under Review
                  </button>
                )}
              </div>
            )}
          </div>
        </div>
      )}

      {/* Student Marks Entry Table */}
      <div className="table-wrap">
        <table className="table">
          <thead>
            <tr>
              <th style={{ width: "60px" }}>#</th>
              <th>Student ID</th>
              <th>Enrollment No</th>
              <th>Student Name</th>
              <th style={{ width: "160px" }}>Marks (Max: {schedule?.max_marks ?? 100})</th>
              <th style={{ width: "120px", textAlign: "center" }}>Absent</th>
              <th>Percentage / Status</th>
            </tr>
          </thead>
          <tbody>
            {loading && (
              <tr>
                <td colSpan={7} className="muted" style={{ textAlign: "center", padding: "30px" }}>
                  Loading student roster...
                </td>
              </tr>
            )}
            {!loading && students.length === 0 && (
              <tr>
                <td colSpan={7} className="muted" style={{ textAlign: "center", padding: "30px" }}>
                  No students found registered or enrolled in this course paper.
                </td>
              </tr>
            )}
            {!loading &&
              students.map((st, idx) => {
                const max = schedule?.max_marks || 100;
                const pass = schedule?.passing_marks || 40;
                const pct = st.marksObtained !== null ? ((st.marksObtained / max) * 100).toFixed(1) : null;
                const isPassing = st.marksObtained !== null && st.marksObtained >= pass;

                return (
                  <tr key={st.studentId} style={st.isAbsent ? { background: "#fff5f5" } : undefined}>
                    <td>{idx + 1}</td>
                    <td><strong>{st.studentId}</strong></td>
                    <td>{st.enrollmentNo}</td>
                    <td>{st.fullName}</td>
                    <td>
                      <input
                        type="number"
                        min={0}
                        max={max}
                        step="0.5"
                        placeholder="--"
                        disabled={isLocked || st.isAbsent}
                        value={st.marksObtained ?? ""}
                        onChange={(e) => updateMark(st.studentId, e.target.value)}
                        style={{
                          width: "120px",
                          fontWeight: 700,
                          borderColor:
                            st.marksObtained !== null && (st.marksObtained < 0 || st.marksObtained > max)
                              ? "var(--danger)"
                              : undefined,
                        }}
                      />
                    </td>
                    <td style={{ textAlign: "center" }}>
                      <input
                        type="checkbox"
                        disabled={isLocked}
                        checked={st.isAbsent}
                        onChange={() => toggleAbsent(st.studentId)}
                      />
                    </td>
                    <td>
                      {st.isAbsent && <Badge tone="danger">ABSENT</Badge>}
                      {!st.isAbsent && st.marksObtained !== null && (
                        <div style={{ display: "inline-flex", alignItems: "center", gap: "8px" }}>
                          <span>{pct}%</span>
                          <Badge tone={isPassing ? "success" : "danger"}>
                            {isPassing ? "PASS" : "FAIL"}
                          </Badge>
                        </div>
                      )}
                      {!st.isAbsent && st.marksObtained === null && (
                        <span className="muted">Pending entry</span>
                      )}
                    </td>
                  </tr>
                );
              })}
          </tbody>
        </table>
      </div>

      {/* Admin Rejection Reason Modal */}
      {showRejectModal && (
        <div className="modal-backdrop" onClick={() => setShowRejectModal(false)}>
          <div className="modal-card" onClick={(e) => e.stopPropagation()}>
            <div className="modal-header">
              <h2>Return Marks Submission for Correction</h2>
              <button className="icon" onClick={() => setShowRejectModal(false)}>✕</button>
            </div>
            <p className="muted">
              Please specify the reason for rejection (e.g., missing absentees, discrepancy in evaluation, out of range marks).
              The faculty instructor will be notified and can edit the draft again.
            </p>
            <label>
              Rejection Reason & Feedback
              <textarea
                rows={4}
                required
                placeholder="Enter specific instructions for the instructor..."
                value={rejectionReason}
                onChange={(e) => setRejectionReason(e.target.value)}
              />
            </label>
            <div className="modal-actions">
              <button className="secondary" onClick={() => setShowRejectModal(false)}>
                Cancel
              </button>
              <button
                style={{ background: "var(--danger)", borderColor: "var(--danger)" }}
                onClick={() => handleAdminReview("REJECT")}
              >
                Confirm Rejection & Return
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
