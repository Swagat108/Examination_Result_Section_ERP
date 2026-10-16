import { ModulePage } from "../../components/ModulePage";

type Row = { code: string; name: string; credits: number; faculty: string; dept: string };

export default function AcademicsPage() {
  return (
    <ModulePage<Row>
      module="academics"
      columns={[
        { header: "Code", render: (r) => r.code },
        { header: "Course", render: (r) => r.name },
        { header: "Credits", render: (r) => r.credits },
        { header: "Faculty", render: (r) => r.faculty },
        { header: "Dept", render: (r) => r.dept },
      ]}
    />
  );
}
