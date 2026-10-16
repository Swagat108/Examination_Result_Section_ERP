import { useState } from "react";
import { NavLink, Outlet } from "react-router-dom";
import { useAuth } from "../auth/AuthContext";
import { Icon } from "../components/Icon";
import { MODULES } from "../modules";

const COLLAPSE_KEY = "erp_sidebar_collapsed";

const readCollapsed = (): boolean => {
  try {
    return localStorage.getItem(COLLAPSE_KEY) === "1";
  } catch {
    return false;
  }
};

export function AppLayout() {
  const { user, logout } = useAuth();
  const [collapsed, setCollapsed] = useState(readCollapsed);
  const visible = MODULES.filter((m) => user?.roles.some((r) => m.roles.includes(r)));

  const toggle = () => {
    const next = !collapsed;
    setCollapsed(next);
    try {
      localStorage.setItem(COLLAPSE_KEY, next ? "1" : "0");
    } catch {
      /* storage unavailable: the toggle still works for this session */
    }
  };

  return (
    <div className="app">
      <header className="topbar">
        <button className="icon" onClick={toggle} aria-label="Toggle sidebar" aria-expanded={!collapsed}>
          <Icon name="menu" />
        </button>
        <span className="brand">
          <span className="brand-mark">UE</span>
          University ERP
        </span>
        <span className="topbar-spacer" />
        <div className="topbar-user">
          <span className="avatar">{user?.username.charAt(0)}</span>
          <span>{user?.username}</span>
          <span className="tag">{user?.roles.join(", ")}</span>
          <button className="secondary" onClick={logout}>
            Log out
          </button>
        </div>
      </header>
      <div className="app-body">
        <aside className={collapsed ? "sidebar collapsed" : "sidebar"}>
          <div className="nav-heading">Menu</div>
          <nav>
            <NavLink to="/" end title="Dashboard">
              <Icon name="dashboard" />
              <span className="nav-label">Dashboard</span>
            </NavLink>
            {visible.map((m) => (
              <NavLink key={m.key} to={m.path} title={m.label}>
                <Icon name={m.key} />
                <span className="nav-label">{m.label}</span>
              </NavLink>
            ))}
          </nav>
        </aside>
        <div className="main">
          <Outlet />
        </div>
      </div>
    </div>
  );
}
