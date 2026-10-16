import { Link } from "react-router-dom";
import { useAuth } from "../../auth/AuthContext";
import { ControlPanel } from "../../components/ControlPanel";
import { MODULES } from "../../modules";

// TODO(G1): replace with vw_university_dashboard KPIs.
export default function DashboardPage() {
  const { user } = useAuth();
  const visible = MODULES.filter((m) => user?.roles.some((r) => m.roles.includes(r)));
  return (
    <>
      <ControlPanel title="Dashboard" subtitle="Pick a module to get started." />
      <div className="content">
        <div className="grid">
          {visible.map((m) => (
            <Link key={m.key} to={m.path} className="card tile">
              <span className="tag">{m.group}</span>
              <strong>{m.label}</strong>
            </Link>
          ))}
        </div>
      </div>
    </>
  );
}
