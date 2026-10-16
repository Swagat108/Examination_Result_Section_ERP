import { Link } from "react-router-dom";
import { useAuth } from "../../auth/AuthContext";
import { MODULES } from "../../modules";

// TODO(G1): replace with vw_university_dashboard KPIs.
export default function DashboardPage() {
  const { user } = useAuth();
  const visible = MODULES.filter((m) => user?.roles.some((r) => m.roles.includes(r)));
  return (
    <>
      <h1>Dashboard</h1>
      <div className="grid">
        {visible.map((m) => (
          <Link key={m.key} to={m.path} className="card tile">
            <span className="badge">{m.group}</span>
            <strong>{m.label}</strong>
          </Link>
        ))}
      </div>
    </>
  );
}
