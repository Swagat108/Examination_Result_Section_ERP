import { ModulePage } from "../../components/ModulePage";

type Row = { driveId: number; company: string; role: string; packageLpa: number; minCgpa: number };

export default function PlacementPage() {
  return (
    <ModulePage<Row>
      module="placement"
      columns={[
        { header: "Drive", render: (r) => r.driveId },
        { header: "Company", render: (r) => r.company },
        { header: "Role", render: (r) => r.role },
        { header: "Package (LPA)", render: (r) => r.packageLpa },
        { header: "Min CGPA", render: (r) => r.minCgpa },
      ]}
    />
  );
}
