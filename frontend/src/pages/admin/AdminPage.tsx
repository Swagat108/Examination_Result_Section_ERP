import { Badge } from "../../components/Badge";
import { ModulePage } from "../../components/ModulePage";

type Row = { id: number; type: string; title: string; audience: string };

export default function AdminPage() {
  return (
    <ModulePage<Row>
      module="admin"
      columns={[
        { header: "ID", render: (r) => r.id },
        { header: "Type", render: (r) => <Badge tone={r.type === "GRIEVANCE" ? "warn" : "neutral"}>{r.type}</Badge> },
        { header: "Title", render: (r) => r.title },
        { header: "Audience", render: (r) => r.audience },
      ]}
    />
  );
}
