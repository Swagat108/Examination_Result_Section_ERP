import { NavLink, Outlet } from "react-router-dom";
import { useAuth } from "../auth/AuthContext";
import { MODULES } from "../modules";

export function AppLayout() {
  const { user, logout } = useAuth();
  const visible = MODULES.filter((m) => user?.roles.some((r) => m.roles.includes(r)));
  return (
    <div className="shell">
      <aside className="sidebar">
        <div className="brand">University ERP</div>
        <nav>
          <NavLink to="/" end>
            Dashboard
          </NavLink>
          {visible.map((m) => (
            <NavLink key={m.key} to={m.path}>
              {m.label}
            </NavLink>
          ))}
        </nav>
      </aside>
      <div className="main">
        <header className="topbar">
          <span>
            {user?.username} <span className="badge">{user?.roles.join(", ")}</span>
          </span>
          <button onClick={logout}>Log out</button>
        </header>
        <main className="content">
          <Outlet />
        </main>
      </div>
    </div>
  );
}
