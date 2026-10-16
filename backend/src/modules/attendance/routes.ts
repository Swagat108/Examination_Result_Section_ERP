import { Router } from "express";
import { requireAuth } from "../../middleware/auth.js";
import { requireRole } from "../../middleware/rbac.js";
import { asyncHandler } from "../../utils/asyncHandler.js";
// import { db } from "../../config/db.js"; // use db().rpc("sp_...") / db().from("vw_...") once Supabase is wired

// G4 - Attendance Management. Replace the sample data with real SQL calls; keep the route shape.
export const attendanceRouter = Router();
attendanceRouter.use(requireAuth);

const sample = [
  { studentId: "2026ETC0001", course: "CS201", attended: 21, total: 30, percentage: 70 },
  { studentId: "2026CMP0001", course: "CS201", attended: 27, total: 30, percentage: 90 },
  { studentId: "2026ITX0001", course: "CS202", attended: 26, total: 30, percentage: 86.7 },
];

attendanceRouter.get(
  "/",
  requireRole("ADMIN", "FACULTY", "STUDENT"),
  asyncHandler(async (_req, res) => {
    res.json({ module: "attendance", group: "G4", title: "Attendance Management", items: sample });
  }),
);
