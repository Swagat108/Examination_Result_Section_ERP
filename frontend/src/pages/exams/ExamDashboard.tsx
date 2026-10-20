import { useEffect, useState } from "react";
import { StatusBadge } from "../../components/Badge";
import { Icon } from "../../components/Icon";
import { api } from "../../lib/api";

interface DashboardData {
  totalExams: number;
  upcomingExams: number;
  ongoingExams: number;
  completedExams: number;
  pendingPublication: number;
  totalResults: number;
  pendingSubmissions: number;
  totalSchedules: number;
  recentExams: Array<{
    exam_id: string;
    exam_name: string;
    exam_type: string;
    sem_no: number;
    start_date: string;
    end_date: string;
    status: string;
  }>;
}

interface ExamDashboardProps {
  onSelectTab: (tab: string) => void;
  isAdmin: boolean;
}

export function ExamDashboard({ onSelectTab, isAdmin }: ExamDashboardProps) {
  const [data, setData] = useState<DashboardData | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  const loadData = () => {
    setLoading(true);
    api<DashboardData>("/exams/dashboard")
      .then((res) => {
        setData(res);
        setError("");
      })
      .catch((err: Error) => setError(err.message))
      .finally(() => setLoading(false));
  };

  useEffect(() => {
    loadData();
  }, []);

  if (loading) {
    return (
      <div className="card" style={{ textAlign: "center", padding: "40px" }}>
        <p className="muted">Loading examination statistics...</p>
      </div>
    );
  }

  if (error) {
    return (
      <div className="form-alert danger">
        Failed to load examination statistics: {error}
      </div>
    );
  }

  return (
    <div style={{ display: "flex", flexDirection: "column", gap: "24px" }}>
      {/* KPI Cards */}
      <div className="stat-grid">
        <div className="card module-card" onClick={() => onSelectTab("exams")} style={{ cursor: "pointer" }}>
          <div className="top">
            <span className="module-icon">
              <Icon name="exams" />
            </span>
            <span className="tag">Total</span>
          </div>
          <strong>Examinations</strong>
          <span className="blurb">Active and archived university exams</span>
          <span className="count">
            {data?.totalExams ?? 0}
            <small>events</small>
          </span>
        </div>

        <div className="card module-card" onClick={() => onSelectTab("exams")} style={{ cursor: "pointer" }}>
          <div className="top">
            <span className="module-icon" style={{ background: "var(--accent-soft)", color: "var(--accent)" }}>
              <Icon name="attendance" />
            </span>
            <span className="badge warn">Upcoming</span>
          </div>
          <strong>Upcoming Exams</strong>
          <span className="blurb">Scheduled or registration open</span>
          <span className="count" style={{ color: "var(--accent)" }}>
            {data?.upcomingExams ?? 0}
            <small>scheduled</small>
          </span>
        </div>

        <div className="card module-card" onClick={() => onSelectTab("exams")} style={{ cursor: "pointer" }}>
          <div className="top">
            <span className="module-icon" style={{ background: "var(--primary-soft)", color: "var(--primary)" }}>
              <Icon name="academics" />
            </span>
            <span className="badge success">Ongoing</span>
          </div>
          <strong>Ongoing Exams</strong>
          <span className="blurb">Currently in progress this session</span>
          <span className="count">
            {data?.ongoingExams ?? 0}
            <small>active</small>
          </span>
        </div>

        <div className="card module-card" onClick={() => onSelectTab("results")} style={{ cursor: "pointer" }}>
          <div className="top">
            <span className="module-icon" style={{ background: "var(--danger-bg)", color: "var(--danger)" }}>
              <Icon name="admin" />
            </span>
            <span className="badge danger">Pending</span>
          </div>
          <strong>Pending Publication</strong>
          <span className="blurb">Completed exams awaiting result declaration</span>
          <span className="count" style={{ color: "var(--danger)" }}>
            {data?.pendingPublication ?? 0}
            <small>to publish</small>
          </span>
        </div>

        <div className="card module-card" onClick={() => onSelectTab("timetable")} style={{ cursor: "pointer" }}>
          <div className="top">
            <span className="module-icon">
              <Icon name="academics" />
            </span>
            <span className="tag">Timetable</span>
          </div>
          <strong>Scheduled Papers</strong>
          <span className="blurb">Course papers slotted into exam dates</span>
          <span className="count">
            {data?.totalSchedules ?? 0}
            <small>papers</small>
          </span>
        </div>

        <div className="card module-card" onClick={() => onSelectTab("results")} style={{ cursor: "pointer" }}>
          <div className="top">
            <span className="module-icon" style={{ background: "var(--success-bg)", color: "var(--success)" }}>
              <Icon name="placement" />
            </span>
            <span className="badge success">Published</span>
          </div>
          <strong>Published Results</strong>
          <span className="blurb">Verified course grade records</span>
          <span className="count" style={{ color: "var(--success)" }}>
            {data?.totalResults ?? 0}
            <small>grades</small>
          </span>
        </div>
        <div className="card module-card" onClick={() => onSelectTab("backlog_forms")} style={{ cursor: "pointer" }}>
          <div className="top">
            <span className="module-icon" style={{ background: "var(--danger-bg)", color: "var(--danger)" }}>
              <Icon name="admin" />
            </span>
            <span className="badge danger">Backlogs</span>
          </div>
          <strong>Backlog Exam Forms</strong>
          <span className="blurb">Exam forms for failed students</span>
          <span className="count" style={{ color: "var(--danger)" }}>
            14
            <small>candidates</small>
          </span>
        </div>
      </div>

      {/* Quick Action Bar for Admin/Staff */}
      <div className="card" style={{ display: "flex", alignItems: "center", justifyContent: "space-between", flexWrap: "wrap", gap: "12px" }}>
        <div>
          <h2 style={{ fontSize: "16px", margin: "0 0 4px" }}>Quick Management Actions</h2>
          <p className="muted" style={{ margin: 0, fontSize: "13px" }}>
            Navigate directly to key examination lifecycle tasks.
          </p>
        </div>
        <div style={{ display: "flex", gap: "10px", flexWrap: "wrap" }}>
          {isAdmin && (
            <button onClick={() => onSelectTab("exams")}>
              + Create Examination
            </button>
          )}
          <button className="secondary" onClick={() => onSelectTab("timetable")}>
            View Timetable
          </button>
          <button className="secondary" onClick={() => onSelectTab("marks")}>
            Marks Entry & Approval
          </button>
          <button className="secondary" onClick={() => onSelectTab("results")}>
            Results & Verification
          </button>
          <button className="secondary" onClick={() => onSelectTab("backlog_forms")}>
            📝 Backlog Exam Forms
          </button>
        </div>
      </div>

      {/* Recent Examinations Overview */}
      <div className="card">
        <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: "16px" }}>
          <h2 style={{ fontSize: "17px", margin: 0 }}>Recent University Examinations</h2>
          <button className="secondary" style={{ fontSize: "13px", padding: "4px 12px" }} onClick={() => onSelectTab("exams")}>
            View All ({data?.totalExams ?? 0})
          </button>
        </div>
        <div className="table-wrap">
          <table className="table">
            <thead>
              <tr>
                <th>Exam ID</th>
                <th>Examination Name</th>
                <th>Type</th>
                <th>Semester</th>
                <th>Start Date</th>
                <th>End Date</th>
                <th>Status</th>
                <th>Action</th>
              </tr>
            </thead>
            <tbody>
              {(!data?.recentExams || data.recentExams.length === 0) && (
                <tr>
                  <td colSpan={8} className="muted">No examination records found.</td>
                </tr>
              )}
              {data?.recentExams.map((e) => (
                <tr key={e.exam_id}>
                  <td><strong>{e.exam_id}</strong></td>
                  <td>{e.exam_name}</td>
                  <td><span className="tag">{e.exam_type}</span></td>
                  <td>Sem {e.sem_no}</td>
                  <td>{e.start_date}</td>
                  <td>{e.end_date}</td>
                  <td><StatusBadge status={e.status} /></td>
                  <td>
                    <button
                      className="secondary"
                      style={{ fontSize: "12px", padding: "4px 10px" }}
                      onClick={() => onSelectTab("exams")}
                    >
                      Manage
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
}
