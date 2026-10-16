import { ModulePage } from "../../components/ModulePage";

type Row = { examId: number; name: string; course: string; date: string; status: string };

export default function ExamsPage() {
  return (
    <ModulePage<Row>
      module="exams"
      columns={[
        { header: "ID", render: (r) => r.examId },
        { header: "Exam", render: (r) => r.name },
        { header: "Course", render: (r) => r.course },
        { header: "Date", render: (r) => r.date },
        { header: "Status", render: (r) => r.status },
      ]}
    />
  );
}
