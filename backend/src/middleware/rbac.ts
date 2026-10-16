import type { NextFunction, Request, Response } from "express";
import type { Role } from "../shared/roles.js";
import { HttpError } from "../utils/httpError.js";

// Usage: router.post("/", requireAuth, requireRole("ADMIN", "FACULTY"), handler)
export const requireRole =
  (...allowed: Role[]) =>
  (req: Request, _res: Response, next: NextFunction) => {
    const roles = req.user?.roles ?? [];
    if (!roles.some((r) => allowed.includes(r))) return next(new HttpError(403, "Forbidden for your role"));
    next();
  };
