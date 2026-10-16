import { Router } from "express";
import { requireAuth } from "../../middleware/auth.js";
import { requireRole } from "../../middleware/rbac.js";
import { asyncHandler } from "../../utils/asyncHandler.js";
// import { db } from "../../config/db.js"; // use db().rpc("sp_...") / db().from("vw_...") once Supabase is wired

// G3 - Academic Management. Replace the sample data with real SQL calls; keep the route shape.
export const academicsRouter = Router();
academicsRouter.use(requireAuth);

const sample = [
  { code: "CS201", name: "Database Systems", credits: 4, faculty: "Dr. Rao", dept: "CMP" },
  { code: "CS202", name: "Operating Systems", credits: 4, faculty: "Dr. Iyer", dept: "CMP" },
  { code: "EC101", name: "Signals and Systems", credits: 3, faculty: "Dr. Nair", dept: "ETC" },
];

academicsRouter.get(
  "/",
  requireRole("ADMIN", "FACULTY", "STUDENT"),
  asyncHandler(async (_req, res) => {
    res.json({ module: "academics", group: "G3", title: "Academic Management", items: sample });
  }),
);
