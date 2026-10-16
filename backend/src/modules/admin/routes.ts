import { Router } from "express";
import { requireAuth } from "../../middleware/auth.js";
import { requireRole } from "../../middleware/rbac.js";
import { asyncHandler } from "../../utils/asyncHandler.js";

// G1 - Communication and Administration. Replace sample data with real SQL calls.
export const adminRouter = Router();
adminRouter.use(requireAuth);

const sample = [
  { id: 1, type: "NOTICE", title: "Welcome to Semester 3", audience: "ETC students" },
  { id: 2, type: "NOTICE", title: "Library timings updated", audience: "All" },
  { id: 3, type: "GRIEVANCE", title: "Hostel Wi-Fi down", audience: "Admin" },
];

adminRouter.get(
  "/",
  requireRole("ADMIN", "FACULTY", "STUDENT", "ACCOUNTANT", "PLACEMENT_OFFICER"),
  asyncHandler(async (_req, res) => {
    res.json({ module: "admin", group: "G1", title: "Communication and Administration", items: sample });
  }),
);
