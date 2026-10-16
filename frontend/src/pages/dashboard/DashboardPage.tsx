import { Link } from "react-router-dom";
import { useAuth } from "../../auth/AuthContext";
import { PageHero } from "../../components/PageHero";
import { MODULES } from "../../modules";

// TODO(G1): replace with vw_university_dashboard KPIs.
export default function DashboardPage() {
  const { user } = useAuth();
  const visible = MODULES.filter((m) => user?.roles.some((r) => m.roles.includes(r)));
  return (
    <>
      <PageHero title="Dashboard" lead="Pick a module to get started." />
      <section className="band band-soft">
        <div className="container">
          <div className="grid">
            {visible.map((m) => (
              <Link key={m.key} to={m.path} className="card tile">
                <span className="tag">{m.group}</span>
                <strong>{m.label}</strong>
              </Link>
            ))}
          </div>
        </div>
      </section>
    </>
  );
}
