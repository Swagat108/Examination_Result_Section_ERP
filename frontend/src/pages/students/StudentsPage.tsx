import { ModulePage } from "../../components/ModulePage";

type Row = { studentId: string; name: string; program: string; semester: number };

export default function StudentsPage() {
  return (
    <ModulePage<Row>
      module="students"
      columns={[
        { header: "Student ID", render: (r) => r.studentId },
        { header: "Name", render: (r) => r.name },
        { header: "Program", render: (r) => r.program },
        { header: "Semester", render: (r) => r.semester },
      ]}
    />
  );
}
