import { useEffect, useState } from "react";
import { StatusBadge } from "../../components/Badge";
import { api } from "../../lib/api";

interface TimetableItem {
  schedule_id: number;
  exam_id: string;
  offering_id: number;
  exam_date: string;
  start_time: string;
  end_time: string;
  max_marks: number;
  passing_marks: number;
  exam?: {
    exam_name: string;
    exam_type: string;
    status: string;
    sem_no: number;
  };
  course_offering?: {
    course_code: string;
    course?: {
      course_title: string;
      course_type: string;
      credits: number;
      dept_code: string;
    };
    employee?: {
      full_name: string;
    };
  };
}

interface ExamTimetableProps {
  isStudent: boolean;
}

export function ExamTimetable({ isStudent }: ExamTimetableProps) {
  const [items, setItems] = useState<TimetableItem[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [search, setSearch] = useState("");
  const [filterExam, setFilterExam] = useState("");

  const loadTimetable = () => {
    setLoading(true);
    api<{ items: TimetableItem[]; message?: string }>("/exams/timetable/all")
      .then((res) => {
        setItems(res.items || []);
        setError("");
      })
      .catch((err: Error) => setError(err.message))
      .finally(() => setLoading(false));
  };

  useEffect(() => {
    loadTimetable();
  }, []);

  const examOptions = Array.from(new Set(items.map((i) => i.exam_id)));

  const filteredItems = items.filter((item) => {
    const q = search.toLowerCase();
    const matchesSearch =
      !q ||
      item.course_offering?.course_code?.toLowerCase().includes(q) ||
      item.course_offering?.course?.course_title?.toLowerCase().includes(q) ||
      item.exam?.exam_name?.toLowerCase().includes(q) ||
      item.exam_id?.toLowerCase().includes(q);

    const matchesExam = !filterExam || item.exam_id === filterExam;
    return matchesSearch && matchesExam;
  });

  return (
    <div style={{ display: "flex", flexDirection: "column", gap: "20px" }}>
      {/* Student notice banner if student */}
      {isStudent && (
        <div className="form-alert success no-print">
          <strong>Personalized Student Timetable:</strong> Showing examinations scheduled exclusively for your registered semester courses.
        </div>
      )}

      {/* Top Filter and Print Bar */}
      <div className="card no-print" style={{ display: "flex", alignItems: "center", justifyContent: "space-between", flexWrap: "wrap", gap: "14px" }}>
        <div style={{ display: "flex", alignItems: "center", gap: "12px", flexWrap: "wrap" }}>
          <input
            type="search"
            placeholder="Search subject or course..."
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            style={{ width: "240px" }}
          />

          {!isStudent && (
            <select
              value={filterExam}
              onChange={(e) => setFilterExam(e.target.value)}
              style={{ width: "200px" }}
            >
              <option value="">All Examinations</option>
              {examOptions.map((e) => (
                <option key={e} value={e}>{e}</option>
              ))}
            </select>
          )}

          <div className="tag">
            {filteredItems.length} papers
          </div>
        </div>

        <button className="secondary" onClick={() => window.print()}>
          🖨️ Print / Save PDF
        </button>
      </div>

      {/* Printable Header */}
      <div className="print-only" style={{ display: "none", textAlign: "center", marginBottom: "20px" }}>
        <h1 style={{ fontSize: "22px", margin: 0 }}>UNIVERSITY EXAMINATION TIMETABLE</h1>
        <p style={{ margin: "4px 0", color: "#555" }}>Official Examination Schedule</p>
        <hr style={{ margin: "10px 0" }} />
      </div>

      {error && <div className="form-alert danger">{error}</div>}

      {/* Timetable Table */}
      <div className="table-wrap">
        <table className="table">
          <thead>
            <tr>
              <th>Date & Day</th>
              <th>Time</th>
              <th>Course / Subject</th>
              <th>Type & Credits</th>
              <th>Examination Event</th>
              <th>Faculty / Invigilator</th>
              <th>Marks</th>
            </tr>
          </thead>
          <tbody>
            {loading && (
              <tr>
                <td colSpan={7} className="muted" style={{ textAlign: "center", padding: "30px" }}>
                  Loading examination schedule...
                </td>
              </tr>
            )}
            {!loading && filteredItems.length === 0 && (
              <tr>
                <td colSpan={7} className="muted" style={{ textAlign: "center", padding: "30px" }}>
                  No examination papers scheduled for the selected criteria.
                </td>
              </tr>
            )}
            {!loading &&
              filteredItems.map((item) => {
                const dateObj = new Date(item.exam_date);
                const dayName = isNaN(dateObj.getTime())
                  ? ""
                  : dateObj.toLocaleDateString(undefined, { weekday: "short" });

                return (
                  <tr key={item.schedule_id}>
                    <td>
                      <div style={{ fontWeight: 700, color: "var(--primary)" }}>
                        {item.exam_date}
                      </div>
                      <div className="muted" style={{ fontSize: "12px" }}>
                        {dayName}
                      </div>
                    </td>
                    <td>
                      <div style={{ fontWeight: 600 }}>
                        {item.start_time.slice(0, 5)} - {item.end_time.slice(0, 5)}
                      </div>
                    </td>
                    <td>
                      <div style={{ fontWeight: 700 }}>
                        {item.course_offering?.course_code}
                      </div>
                      <div style={{ fontSize: "13px" }}>
                        {item.course_offering?.course?.course_title}
                      </div>
                    </td>
                    <td>
                      <span className="tag" style={{ marginRight: "6px" }}>
                        {item.course_offering?.course?.course_type || "THEORY"}
                      </span>
                      <small className="muted">{item.course_offering?.course?.credits ?? 3} cr</small>
                    </td>
                    <td>
                      <div style={{ fontSize: "13px", fontWeight: 600 }}>
                        {item.exam?.exam_name || item.exam_id}
                      </div>
                      <div className="muted" style={{ fontSize: "11px" }}>
                        Sem {item.exam?.sem_no} • <StatusBadge status={item.exam?.status || "SCHEDULED"} />
                      </div>
                    </td>
                    <td>
                      {item.course_offering?.employee?.full_name || "Department Allocated"}
                    </td>
                    <td>
                      <span className="tag" style={{ background: "var(--accent-soft)", color: "var(--accent)" }}>
                        Max: {item.max_marks} (Pass: {item.passing_marks})
                      </span>
                    </td>
                  </tr>
                );
              })}
          </tbody>
        </table>
      </div>
    </div>
  );
}
