import { Router } from "express";
import { requireAuth } from "../../middleware/auth.js";
import { requireRole } from "../../middleware/rbac.js";
import { asyncHandler } from "../../utils/asyncHandler.js";
// import { db } from "../../config/db.js"; // use db().rpc("sp_...") / db().from("vw_...") once Supabase is wired

// G5 - Fees and Finance Management. Replace the sample data with real SQL calls; keep the route shape.
export const financeRouter = Router();
financeRouter.use(requireAuth);

const sample = [
  { invoiceId: 1001, studentId: "2026ETC0001", amount: 85000, paid: 40000, status: "PARTIAL" },
  { invoiceId: 1002, studentId: "2026CMP0001", amount: 85000, paid: 85000, status: "PAID" },
  { invoiceId: 1003, studentId: "2026ITX0001", amount: 85000, paid: 0, status: "DUE" },
];

financeRouter.get(
  "/",
  requireRole("ADMIN", "ACCOUNTANT", "STUDENT"),
  asyncHandler(async (_req, res) => {
    res.json({ module: "finance", group: "G5", title: "Fees and Finance Management", items: sample });
  }),
);
