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
        { header: "%", render: (r) => r.percentage },
      ]}
    />
  );
}
