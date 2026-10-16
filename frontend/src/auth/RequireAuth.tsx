import { Navigate, Outlet, useLocation } from "react-router-dom";
import { useAuth } from "./AuthContext";
import type { Role } from "./types";

export function RequireAuth({ roles }: { roles?: readonly Role[] }) {
  const { user, loading } = useAuth();
  const location = useLocation();
  if (loading) return <p className="muted">Loading...</p>;
  if (!user) return <Navigate to="/login" state={{ from: location }} replace />;
  if (roles && !user.roles.some((r) => roles.includes(r))) return <Navigate to="/" replace />;
  return <Outlet />;
}
