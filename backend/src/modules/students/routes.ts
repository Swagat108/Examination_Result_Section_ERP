import { Router } from "express";
import { requireAuth } from "../../middleware/auth.js";
import { requireRole } from "../../middleware/rbac.js";
import { asyncHandler } from "../../utils/asyncHandler.js";
// import { db } from "../../config/db.js"; // use db().rpc("sp_...") / db().from("vw_...") once Supabase is wired

// G6 - Student Management. Replace the sample data with real SQL calls; keep the route shape.
export const studentsRouter = Router();
studentsRouter.use(requireAuth);

const sample = [
  { studentId: "2026ETC0001", name: "Priya Sharma", program: "B.Tech ETC", semester: 3 },
  { studentId: "2026CMP0001", name: "Rahul Verma", program: "B.Tech CMP", semester: 3 },
  { studentId: "2026ITX0001", name: "Sneha Patil", program: "B.Tech ITX", semester: 3 },
];

studentsRouter.get(
  "/",
  requireRole("ADMIN", "FACULTY"),
  asyncHandler(async (_req, res) => {
    res.json({ module: "students", group: "G6", title: "Student Management", items: sample });
  }),
);
