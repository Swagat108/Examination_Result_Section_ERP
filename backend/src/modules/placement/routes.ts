import { Router } from "express";
import { requireAuth } from "../../middleware/auth.js";
import { requireRole } from "../../middleware/rbac.js";
import { asyncHandler } from "../../utils/asyncHandler.js";
// import { db } from "../../config/db.js"; // use db().rpc("sp_...") / db().from("vw_...") once Supabase is wired

// G7 - Placement and Career Management. Replace the sample data with real SQL calls; keep the route shape.
export const placementRouter = Router();
placementRouter.use(requireAuth);

const sample = [
  { driveId: 1, company: "Acme Tech", role: "SDE", packageLpa: 12, minCgpa: 7.5 },
  { driveId: 2, company: "DataWorks", role: "Data Analyst", packageLpa: 9, minCgpa: 7.0 },
  { driveId: 3, company: "CloudNine", role: "DevOps Engineer", packageLpa: 14, minCgpa: 8.0 },
];

placementRouter.get(
  "/",
  requireRole("ADMIN", "PLACEMENT_OFFICER", "STUDENT"),
  asyncHandler(async (_req, res) => {
    res.json({ module: "placement", group: "G7", title: "Placement and Career Management", items: sample });
  }),
);
