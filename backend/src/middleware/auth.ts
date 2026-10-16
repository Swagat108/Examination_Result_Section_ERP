import type { NextFunction, Request, Response } from "express";
import jwt from "jsonwebtoken";
import { env } from "../config/env.js";
import type { AuthUser } from "../shared/roles.js";
import { HttpError } from "../utils/httpError.js";

declare module "express-serve-static-core" {
  interface Request {
    user?: AuthUser;
  }
}

export const signToken = (user: AuthUser): string =>
  jwt.sign(user, env.jwtSecret, { expiresIn: env.jwtExpiresIn } as jwt.SignOptions);

export const requireAuth = (req: Request, _res: Response, next: NextFunction) => {
  const header = req.headers.authorization;
  if (!header?.startsWith("Bearer ")) return next(new HttpError(401, "Missing bearer token"));
  try {
    req.user = jwt.verify(header.slice(7), env.jwtSecret) as AuthUser;
    next();
  } catch {
    next(new HttpError(401, "Invalid or expired token"));
  }
};
