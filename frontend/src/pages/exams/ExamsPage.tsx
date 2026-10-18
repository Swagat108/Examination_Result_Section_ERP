import { useState } from "react";
import { useAuth } from "../../auth/AuthContext";
import { ControlPanel } from "../../components/ControlPanel";
import { ExamDashboard } from "./ExamDashboard";
import { ExamList } from "./ExamList";
import { ExamTimetable } from "./ExamTimetable";
import { MarksEntry } from "./MarksEntry";
import { ResultManagement } from "./ResultManagement";
import { StudentResultPortal } from "./StudentResultPortal";

export default function ExamsPage() {
  const { user } = useAuth();

  const isAdmin = Boolean(user?.roles.includes("ADMIN"));
  const isFaculty = Boolean(user?.roles.includes("FACULTY"));
  const isStudent = Boolean(user?.roles.includes("STUDENT"));

  // Default initial tab based on role
  const defaultTab = isStudent ? "my_results" : isFaculty ? "marks" : "dashboard";
  const [activeTab, setActiveTab] = useState<string>(defaultTab);
  const [preselectedExamId, setPreselectedExamId] = useState<string>("");

  const handleNavigateToMarks = (examId: string) => {
    setPreselectedExamId(examId);
    setActiveTab("marks");
  };

  const tabs = [
    ...(isStudent
      ? [{ key: "my_results", label: "🎓 My Results & Transcript" }]
      : []),
    { key: "dashboard", label: "📊 Overview Dashboard" },
    ...(!isStudent ? [{ key: "exams", label: "📋 Examination Events" }] : []),
    { key: "timetable", label: "🗓️ Examination Timetable" },
    ...(!isStudent ? [{ key: "marks", label: "✍️ Marks Entry & Approval" }] : []),
    ...(!isStudent ? [{ key: "results", label: "🏆 Results & Publication" }] : []),
  ];

  return (
    <>
      <ControlPanel
        title="Examination and Results Management"
        subtitle={
          isStudent
            ? `Student Portal • Candidate: ${user?.username} (${user?.studentId || "2024ETC0003"})`
            : isFaculty
            ? `Faculty Evaluation Portal • Instructor: ${user?.username} (${user?.employeeId || "EMP0101"})`
            : "University Examination Cell • Administrative Operations"
        }
      >
        <span className="tag">{user?.roles.join(", ")}</span>
      </ControlPanel>

      {/* Module Sub-Tabs Bar */}
      <div className="exam-tabs no-print">
        {tabs.map((t) => (
          <button
            key={t.key}
            className={`exam-tab-btn ${activeTab === t.key ? "active" : ""}`}
            onClick={() => setActiveTab(t.key)}
          >
            {t.label}
          </button>
        ))}
      </div>

      {/* Main Content Area */}
      <div className="content">
        {activeTab === "dashboard" && (
          <ExamDashboard onSelectTab={setActiveTab} isAdmin={isAdmin} />
        )}

        {activeTab === "exams" && (
          <ExamList isAdmin={isAdmin} onNavigateToMarks={handleNavigateToMarks} />
        )}

        {activeTab === "timetable" && (
          <ExamTimetable isStudent={isStudent} />
        )}

        {activeTab === "marks" && (
          <MarksEntry isAdmin={isAdmin} preselectedExamId={preselectedExamId} />
        )}

        {activeTab === "results" && (
          <ResultManagement isAdmin={isAdmin} />
        )}

        {activeTab === "my_results" && (
          <StudentResultPortal />
        )}
      </div>
    </>
  );
}
