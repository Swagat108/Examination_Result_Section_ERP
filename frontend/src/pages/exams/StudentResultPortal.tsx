import { useEffect, useState } from "react";
import { Badge } from "../../components/Badge";
import { api } from "../../lib/api";

interface CourseResult {
  resultId: number;
  courseCode: string;
  courseTitle: string;
  courseType: string;
  credits: number;
  totalMarks: number;
  maxMarks: number;
  percentage: number;
  grade: string;
  publishedOn: string;
}

interface SemesterData {
  semesterId: number;
  term: string;
  academicYear: string;
  sgpa: number | null;
  courses: CourseResult[];
}

interface StudentResultData {
  student: {
    student_id: string;
    enrollment_no: string;
    full_name: string;
    email: string;
    admission_year: number;
    program?: {
      program_name: string;
      program_code: string;
      degree_level: string;
    };
  };
  cgpa: number | null;
  semesters: SemesterData[];
}

interface StudentResultPortalProps {
  onNavigateToBacklogForm?: () => void;
}

export function StudentResultPortal({ onNavigateToBacklogForm }: StudentResultPortalProps) {
  const [data, setData] = useState<StudentResultData | null>(null);
  const [selectedSemId, setSelectedSemId] = useState<number>(0);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  const downloadGradeSheet = () => {
    const originalTitle = document.title;
    const safeName = data?.student.full_name.replace(/[^a-z0-9]+/gi, "-").replace(/^-|-$/g, "") || "student";
    document.title = `${safeName}-${activeSemester.academicYear}-${activeSemester.term}-grade-sheet`;
    window.print();
    window.setTimeout(() => {
      document.title = originalTitle;
    }, 1000);
  };

  useEffect(() => {
    setLoading(true);
    api<StudentResultData>("/exams/student/results")
      .then((res) => {
        setData(res);
        if (res.semesters && res.semesters.length > 0) {
          setSelectedSemId(res.semesters[0].semesterId);
        }
        setError("");
      })
      .catch((err: Error) => setError(err.message))
      .finally(() => setLoading(false));
  }, []);

  if (loading) {
    return (
      <div className="card" style={{ textAlign: "center", padding: "40px" }}>
        <p className="muted">Retrieving your official examination grade sheets...</p>
      </div>
    );
  }

  if (error) {
    return (
      <div className="form-alert danger">
        Unable to load student results: {error}
      </div>
    );
  }

  if (!data || !data.semesters || data.semesters.length === 0) {
    return (
      <div className="card" style={{ textAlign: "center", padding: "40px" }}>
        <h2>No Published Results Available</h2>
        <p className="muted">
          Your examinations are either scheduled or awaiting official evaluation and declaration.
          Once the examination cell publishes the verified results, they will be accessible here.
        </p>
      </div>
    );
  }

  const activeSemester = data.semesters.find((s) => s.semesterId === selectedSemId) || data.semesters[0];

  const totalCredits = activeSemester.courses.reduce((acc, c) => acc + (c.credits || 0), 0);
  const totalObtained = activeSemester.courses.reduce((acc, c) => acc + (c.totalMarks || 0), 0);
  const totalMax = activeSemester.courses.reduce((acc, c) => acc + (c.maxMarks || 0), 0);
  const semPercentage = totalMax > 0 ? ((totalObtained / totalMax) * 100).toFixed(2) : "0.00";

  // Check for any backlogs across all published results
  const allBacklogs = data.semesters.flatMap((s) => s.courses).filter((c) => c.grade === "F");
  return (
    <div style={{ display: "flex", flexDirection: "column", gap: "24px" }}>
      {/* Student Banner and Cumulative CGPA Card */}
      <div className="result-card-banner">
        <div style={{ display: "flex", justifyContent: "space-between", alignItems: "flex-start", flexWrap: "wrap", gap: "16px" }}>
          <div>
            <span className="badge success" style={{ marginBottom: "8px" }}>STUDENT ACADEMIC RECORD</span>
            <h2 style={{ fontSize: "24px", color: "#fff", margin: "4px 0" }}>
              {data.student.full_name}
            </h2>
            <div style={{ color: "#dcebe4", fontSize: "14px" }}>
              Enrollment No: <b>{data.student.enrollment_no}</b> • Student ID: <b>{data.student.student_id}</b>
            </div>
            <div style={{ color: "#b6cdc3", fontSize: "13px", marginTop: "4px" }}>
              Program: <b>{data.student.program?.program_name || "B.Tech"}</b> ({data.student.program?.program_code || "ENG"}) • Batch {data.student.admission_year}
            </div>
          </div>

          <button
            className="secondary no-print"
            onClick={downloadGradeSheet}
            style={{ color: "var(--text)", padding: "10px 18px", fontSize: "14px", fontWeight: 700 }}
          >
            Download Grade Sheet PDF
          </button>
        </div>

        <div className="result-stat-row">
          <div className="result-stat-box" style={{ background: "rgba(255, 255, 255, 0.2)" }}>
            <small>Cumulative CGPA</small>
            <strong style={{ fontSize: "32px", color: "#fff" }}>
              {data.cgpa !== null ? Number(data.cgpa).toFixed(2) : "--"}
            </strong>
          </div>

          <div className="result-stat-box">
            <small>Active Term SGPA</small>
            <strong style={{ fontSize: "32px", color: "var(--accent)" }}>
              {activeSemester.sgpa !== null ? Number(activeSemester.sgpa).toFixed(2) : "--"}
            </strong>
          </div>

          <div className="result-stat-box">
            <small>Semester Percentage</small>
            <strong>{semPercentage}%</strong>
          </div>

          <div className="result-stat-box">
            <small>Credits Registered</small>
            <strong>{totalCredits} cr</strong>
          </div>
        </div>
      </div>

      {/* Backlog / Failed Course Action Banner */}
      {allBacklogs.length > 0 && (
        <div
          className="card no-print"
          style={{
            background: "#fff1f2",
            border: "1px solid #fecdd3",
            padding: "16px 20px",
            display: "flex",
            justifyContent: "space-between",
            alignItems: "center",
            flexWrap: "wrap",
            gap: "12px",
          }}
        >
          <div>
            <h3 style={{ margin: "0 0 4px", color: "var(--danger)", fontSize: "16px", display: "flex", alignItems: "center", gap: "8px" }}>
              <span>⚠️</span>
              Re-examination Required: {allBacklogs.length} Pending Course Backlog(s)
            </h3>
            <p style={{ margin: 0, fontSize: "13px", color: "#881337" }}>
              You have unsatisfied requirements with Grade 'F' in:{" "}
              <b>{allBacklogs.map((b) => `${b.courseCode} (${b.courseTitle})`).join(", ")}</b>.
              The University Examination Cell has opened the Backlog / Supplementary Exam Form window.
            </p>
          </div>

          {onNavigateToBacklogForm && (
            <button
              onClick={onNavigateToBacklogForm}
              style={{
                padding: "9px 20px",
                fontWeight: 700,
                background: "var(--danger)",
                color: "#fff",
                border: "none",
                borderRadius: "var(--radius-control)",
                cursor: "pointer",
              }}
            >
              Fill Backlog Exam Form →
            </button>
          )}
        </div>
      )}
      {/* Printable Official University Header */}
      <div className="print-only" style={{ display: "none", textAlign: "center", marginBottom: "20px" }}>
        <h1 style={{ fontSize: "24px", margin: "0 0 4px", fontWeight: 700, color: "#1d5c4d" }}>
          UNIVERSITY OF ENGINEERING & TECHNOLOGY
        </h1>
        <p style={{ margin: "2px 0", fontSize: "14px", color: "#444" }}>
          OFFICE OF THE CONTROLLER OF EXAMINATIONS
        </p>
        <p style={{ margin: "2px 0", fontSize: "16px", fontWeight: 700 }}>
          GRADE CARD / TRANSCRIPT RECORD
        </p>
        <div style={{ display: "flex", justifyContent: "space-between", margin: "16px 0 10px", padding: "10px", border: "1px solid #999", borderRadius: "8px", fontSize: "13px" }}>
          <div style={{ textAlign: "left" }}>
            <div>Candidate Name: <b>{data.student.full_name}</b></div>
            <div>Enrollment Number: <b>{data.student.enrollment_no}</b></div>
          </div>
          <div style={{ textAlign: "left" }}>
            <div>Degree Program: <b>{data.student.program?.program_name}</b></div>
            <div>Semester / Term: <b>{activeSemester.academicYear} ({activeSemester.term})</b></div>
          </div>
        </div>
      </div>

      {/* Semester Selector Tabs */}
      <div className="no-print card" style={{ display: "flex", gap: "14px", flexWrap: "wrap", alignItems: "center", padding: "14px 18px" }}>
        <label htmlFor="grade-sheet-semester" style={{ margin: 0, fontWeight: 700 }}>
          Select semester
        </label>
        <select
          id="grade-sheet-semester"
          value={activeSemester.semesterId}
          onChange={(event) => setSelectedSemId(Number(event.target.value))}
          style={{ width: "auto", minWidth: "280px", maxWidth: "100%" }}
        >
          {data.semesters.map((semester) => (
            <option key={semester.semesterId} value={semester.semesterId}>
              {semester.academicYear} {semester.term} Term (SGPA: {semester.sgpa !== null ? Number(semester.sgpa).toFixed(2) : "--"})
            </option>
          ))}
        </select>
        <span className="muted" aria-live="polite">
          Showing {activeSemester.academicYear} {activeSemester.term} grade sheet
        </span>
      </div>

      <div className="card no-print" style={{ padding: 0, overflow: "hidden" }}>
        <div style={{ padding: "16px 20px", borderBottom: "1px solid var(--border)" }}>
          <h3 style={{ margin: 0, fontSize: "17px" }}>Published Results History</h3>
          <p className="muted" style={{ margin: "4px 0 0", fontSize: "13px" }}>
            Select any current or past published semester to view its complete grade sheet.
          </p>
        </div>
        <table className="table" style={{ margin: 0 }}>
          <thead>
            <tr>
              <th>Academic Year</th>
              <th>Term</th>
              <th>Courses</th>
              <th>SGPA</th>
              <th className="no-print">Grade Sheet</th>
            </tr>
          </thead>
          <tbody>
            {data.semesters.map((semester) => (
              <tr key={semester.semesterId}>
                <td>{semester.academicYear}</td>
                <td>{semester.term}</td>
                <td>{semester.courses.length}</td>
                <td>{semester.sgpa !== null ? Number(semester.sgpa).toFixed(2) : "--"}</td>
                <td className="no-print">
                  <button
                    type="button"
                    className={semester.semesterId === activeSemester.semesterId ? "" : "secondary"}
                    aria-current={semester.semesterId === activeSemester.semesterId ? "true" : undefined}
                    onClick={() => setSelectedSemId(semester.semesterId)}
                    style={{ padding: "5px 12px" }}
                  >
                    {semester.semesterId === activeSemester.semesterId ? "Viewing" : "View results"}
                  </button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      {/* Subject-Wise Marksheet Table */}
      <div className="card" style={{ padding: "0", overflow: "hidden" }}>
        <div style={{ padding: "18px 24px", borderBottom: "1px solid var(--border)", display: "flex", justifyContent: "space-between", alignItems: "center" }}>
          <h3 style={{ margin: 0, fontSize: "17px" }}>
            Subject Performance • {activeSemester.academicYear} {activeSemester.term} Semester
          </h3>
          <span className="tag" style={{ fontSize: "13px" }}>
            Semester SGPA: <b>{activeSemester.sgpa !== null ? Number(activeSemester.sgpa).toFixed(2) : "--"} / 10.0</b>
          </span>
        </div>

        <table className="table" style={{ margin: 0 }}>
          <thead>
            <tr>
              <th>Course Code</th>
              <th>Course Title</th>
              <th>Type</th>
              <th>Credits</th>
              <th>Max Marks</th>
              <th>Obtained Marks</th>
              <th>Percentage</th>
              <th style={{ textAlign: "center" }}>Grade</th>
              <th>Status</th>
            </tr>
          </thead>
          <tbody>
            {activeSemester.courses.map((c) => {
              const isPass = c.grade !== "F";
              return (
                <tr key={c.resultId}>
                  <td><strong>{c.courseCode}</strong></td>
                  <td>{c.courseTitle}</td>
                  <td><span className="tag">{c.courseType}</span></td>
                  <td><b>{c.credits}</b></td>
                  <td>{c.maxMarks}</td>
                  <td><b>{c.totalMarks}</b></td>
                  <td>{c.percentage}%</td>
                  <td style={{ textAlign: "center" }}>
                    <span className={`grade-badge grade-${c.grade.replace("+", "-plus")}`}>
                      {c.grade}
                    </span>
                  </td>
                  <td>
                    <Badge tone={isPass ? "success" : "danger"}>
                      {isPass ? "PASS" : "FAIL"}
                    </Badge>
                  </td>
                </tr>
              );
            })}
          </tbody>
          <tfoot>
            <tr style={{ background: "#f8faf7", fontWeight: 700 }}>
              <td colSpan={3}>Semester Aggregate Summary</td>
              <td>{totalCredits} cr</td>
              <td>{totalMax}</td>
              <td>{totalObtained}</td>
              <td>{semPercentage}%</td>
              <td style={{ textAlign: "center" }}>
                <span className="badge success">
                  SGPA: {activeSemester.sgpa !== null ? Number(activeSemester.sgpa).toFixed(2) : "--"}
                </span>
              </td>
              <td>
                <Badge tone="success">COMPLETED</Badge>
              </td>
            </tr>
          </tfoot>
        </table>
      </div>

      {/* Official Signatures & Verification (Shown in Print) */}
      <div className="print-only" style={{ display: "none", marginTop: "40px" }}>
        <div style={{ display: "flex", justifyContent: "space-between", marginTop: "60px", padding: "0 40px", textAlign: "center" }}>
          <div>
            <div style={{ borderBottom: "1px solid #333", width: "180px", marginBottom: "6px" }}></div>
            <p style={{ margin: 0, fontSize: "12px", fontWeight: 600 }}>Checked By (Verification)</p>
          </div>
          <div>
            <div style={{ borderBottom: "1px solid #333", width: "180px", marginBottom: "6px" }}></div>
            <p style={{ margin: 0, fontSize: "12px", fontWeight: 600 }}>Controller of Examinations</p>
          </div>
        </div>
        <p style={{ fontSize: "11px", color: "#666", textAlign: "center", marginTop: "30px" }}>
          This is a computer-generated official grade report issued by the University ERP Examination Management System.
        </p>
      </div>

      {/* Grading Scale Legend */}
      <div className="card" style={{ padding: "16px 20px" }}>
        <h4 style={{ margin: "0 0 10px", fontSize: "14px", color: "var(--muted)" }}>
          INSTITUTIONAL 10-POINT GRADING SYSTEM KEY
        </h4>
        <div style={{ display: "flex", flexWrap: "wrap", gap: "12px", fontSize: "12px" }}>
          <span><b>O</b> (90-100%, 10.0 GP - Outstanding)</span>
          <span>•</span>
          <span><b>A+</b> (80-89%, 9.0 GP - Excellent)</span>
          <span>•</span>
          <span><b>A</b> (70-79%, 8.0 GP - Very Good)</span>
          <span>•</span>
          <span><b>B+</b> (60-69%, 7.0 GP - Good)</span>
          <span>•</span>
          <span><b>B</b> (55-59%, 6.0 GP - Above Avg)</span>
          <span>•</span>
          <span><b>C</b> (50-54%, 5.0 GP - Average)</span>
          <span>•</span>
          <span><b>P</b> (40-49%, 4.0 GP - Pass)</span>
          <span>•</span>
          <span style={{ color: "var(--danger)" }}><b>F</b> (&lt;40%, 0.0 GP - Fail)</span>
        </div>
      </div>
    </div>
  );
}
