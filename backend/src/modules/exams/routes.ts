import { Router } from "express";
import { requireAuth } from "../../middleware/auth.js";
import { requireRole } from "../../middleware/rbac.js";
import { asyncHandler } from "../../utils/asyncHandler.js";
// import { db } from "../../config/db.js"; // use db().rpc("sp_...") / db().from("vw_...") once Supabase is wired

// G2 - Examination and Results Management. Replace the sample data with real SQL calls; keep the route shape.
export const examsRouter = Router();
examsRouter.use(requireAuth);

const sample = [
  { examId: 1, name: "End Semester 3", course: "CS201", date: "2026-12-05", status: "SCHEDULED" },
  { examId: 2, name: "End Semester 3", course: "CS202", date: "2026-12-08", status: "SCHEDULED" },
  { examId: 3, name: "Mid Semester 3", course: "EC101", date: "2026-10-01", status: "RESULTS_PUBLISHED" },
];

examsRouter.get(
  "/",
  requireRole("ADMIN", "FACULTY", "STUDENT"),
  asyncHandler(async (_req, res) => {
    res.json({ module: "exams", group: "G2", title: "Examination and Results Management", items: sample });
  }),
);
