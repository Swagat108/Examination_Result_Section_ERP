import { NavLink, Outlet } from "react-router-dom";
import { useAuth } from "../auth/AuthContext";
import { MODULES } from "../modules";

export function AppLayout() {
  const { user, logout } = useAuth();
  const visible = MODULES.filter((m) => user?.roles.some((r) => m.roles.includes(r)));
  return (
    <>
      <header className="masthead">
        <div className="container">
          <span className="wordmark">University ERP</span>
          <div className="masthead-user">
            <span>
              {user?.username} <span className="tag">{user?.roles.join(", ")}</span>
            </span>
            <button className="secondary" onClick={logout}>
              Log out
            </button>
          </div>
        </div>
      </header>
      <div className="subnav">
        <div className="container">
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
        </div>
      </div>
      <main>
        <Outlet />
      </main>
      <footer className="footer">
        <div className="container">DBMS PBL Activity - University ERP</div>
      </footer>
    </>
  );
}
