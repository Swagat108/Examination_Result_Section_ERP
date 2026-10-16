import { useEffect, useState } from "react";
import { Link } from "react-router-dom";
import { useAuth } from "../../auth/AuthContext";
import { ControlPanel } from "../../components/ControlPanel";
import { Icon } from "../../components/Icon";
import { api } from "../../lib/api";
import { MODULES } from "../../modules";

// TODO(G1): replace the record counts with vw_university_dashboard KPIs.
export default function DashboardPage() {
  const { user } = useAuth();
  const visible = MODULES.filter((m) => user?.roles.some((r) => m.roles.includes(r)));
  const [counts, setCounts] = useState<Record<string, number>>({});

  useEffect(() => {
    Promise.allSettled(visible.map((m) => api<{ items: unknown[] }>(`/${m.key}`))).then((results) => {
      const next: Record<string, number> = {};
      results.forEach((r, i) => {
        if (r.status === "fulfilled") next[visible[i].key] = r.value.items.length;
      });
      setCounts(next);
    });
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [user]);

  const today = new Date().toLocaleDateString(undefined, { weekday: "long", day: "numeric", month: "long", year: "numeric" });

  return (
    <>
      <ControlPanel title="Dashboard" subtitle={today} />
      <div className="content">
        <section className="banner">
          <div className="rule" />
          <h2>Welcome back, {user?.username}</h2>
          <p>
            You have access to {visible.length} modules.
          </p>
          <p style={{ marginTop: 12 }}>
            {user?.roles.map((r) => (
              <span key={r} className="tag">
                {r.replace(/_/g, " ")}
              </span>
            ))}
          </p>
        </section>
        <div className="stat-grid">
          {visible.map((m) => (
            <Link key={m.key} to={m.path} className="card module-card">
              <div className="top">
                <span className="module-icon">
                  <Icon name={m.key} />
                </span>
                <span className="tag">{m.group}</span>
              </div>
              <strong>{m.label}</strong>
              <span className="blurb">{m.blurb}</span>
              <span className="count">
                {counts[m.key] ?? "-"}
                <small>records</small>
              </span>
            </Link>
          ))}
        </div>
      </div>
    </>
  );
}
