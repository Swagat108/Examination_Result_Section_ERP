import { Badge } from "../../components/Badge";
import { ModulePage } from "../../components/ModulePage";

type Row = { studentId: string; course: string; attended: number; total: number; percentage: number };

export default function AttendancePage() {
  return (
    <ModulePage<Row>
      module="attendance"
      columns={[
        { header: "Student", render: (r) => r.studentId },
        { header: "Course", render: (r) => r.course },
        { header: "Attended", render: (r) => r.attended },
        { header: "Total", render: (r) => r.total },
        {
          header: "Attendance",
          render: (r) => (
            <Badge tone={r.percentage < 75 ? "danger" : r.percentage < 85 ? "warn" : "success"}>{r.percentage}%</Badge>
          ),
        },
      ]}
    />
  );
}
