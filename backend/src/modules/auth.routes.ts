import { Router } from "express";
import { z } from "zod";
import { requireAuth, signToken } from "../middleware/auth.js";
import { ROLES, type AuthUser } from "../shared/roles.js";
import { asyncHandler } from "../utils/asyncHandler.js";
import { HttpError } from "../utils/httpError.js";

export const authRouter = Router();

// TODO(G1): replace with a lookup on app_user + user_role and bcrypt.compare against password_hash.
const DEV_PASSWORD = "password123";
const devUsers: AuthUser[] = [
  { id: 1, username: "admin", email: "admin@erp.test", roles: ["ADMIN"] },
  { id: 2, username: "faculty", email: "faculty@erp.test", roles: ["FACULTY"] },
  { id: 3, username: "student", email: "student@erp.test", roles: ["STUDENT"] },
  { id: 4, username: "accountant", email: "accountant@erp.test", roles: ["ACCOUNTANT"] },
  { id: 5, username: "placement", email: "placement@erp.test", roles: ["PLACEMENT_OFFICER"] },
];

const loginSchema = z.object({ username: z.string().min(1), password: z.string().min(1) });

authRouter.post(
  "/login",
  asyncHandler(async (req, res) => {
    const { username, password } = loginSchema.parse(req.body);
    const user = devUsers.find((u) => u.username === username);
    if (!user || password !== DEV_PASSWORD) throw new HttpError(401, "Invalid username or password");
    res.json({ token: signToken(user), user });
  }),
);

authRouter.get("/me", requireAuth, (req, res) => {
  res.json({ user: req.user });
});

authRouter.get("/roles", (_req, res) => {
  res.json({ roles: ROLES });
});
