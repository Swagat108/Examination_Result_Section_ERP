import type { ReactElement } from "react";
import { Route, Routes } from "react-router-dom";
import { RequireAuth } from "./auth/RequireAuth";
import { AppLayout } from "./layouts/AppLayout";
import { MODULES } from "./modules";
import AcademicsPage from "./pages/academics/AcademicsPage";
import AdminPage from "./pages/admin/AdminPage";
import AttendancePage from "./pages/attendance/AttendancePage";
import DashboardPage from "./pages/dashboard/DashboardPage";
import ExamsPage from "./pages/exams/ExamsPage";
import FinancePage from "./pages/finance/FinancePage";
import LoginPage from "./pages/login/LoginPage";
import PlacementPage from "./pages/placement/PlacementPage";
import StudentsPage from "./pages/students/StudentsPage";

const PAGES: Record<string, ReactElement> = {
  admin: <AdminPage />,
  academics: <AcademicsPage />,
  students: <StudentsPage />,
  attendance: <AttendancePage />,
  finance: <FinancePage />,
  exams: <ExamsPage />,
  placement: <PlacementPage />,
};

export default function App() {
  return (
    <Routes>
      <Route path="/login" element={<LoginPage />} />
      <Route element={<RequireAuth />}>
        <Route element={<AppLayout />}>
          <Route index element={<DashboardPage />} />
          {MODULES.map((m) => (
            <Route key={m.key} element={<RequireAuth roles={m.roles} />}>
              <Route path={m.path} element={PAGES[m.key]} />
            </Route>
          ))}
        </Route>
      </Route>
    </Routes>
  );
}
