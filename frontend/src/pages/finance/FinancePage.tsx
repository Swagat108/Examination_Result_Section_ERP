import { StatusBadge } from "../../components/Badge";
import { ModulePage } from "../../components/ModulePage";

type Row = { invoiceId: number; studentId: string; amount: number; paid: number; status: string };

export default function FinancePage() {
  return (
    <ModulePage<Row>
      module="finance"
      columns={[
        { header: "Invoice", render: (r) => r.invoiceId },
        { header: "Student", render: (r) => r.studentId },
        { header: "Amount", render: (r) => r.amount },
        { header: "Paid", render: (r) => r.paid },
        { header: "Status", render: (r) => <StatusBadge status={r.status} /> },
      ]}
    />
  );
}
