import type { NextFunction, Request, Response } from "express";
import { ZodError } from "zod";
import { HttpError } from "../utils/httpError.js";

export const notFound = (_req: Request, _res: Response, next: NextFunction) =>
  next(new HttpError(404, "Route not found"));

export const errorHandler = (err: unknown, _req: Request, res: Response, _next: NextFunction) => {
  if (err instanceof HttpError) return res.status(err.status).json({ error: err.message });
  if (err instanceof ZodError) return res.status(400).json({ error: "Validation failed", details: err.flatten() });
  console.error(err);
  res.status(500).json({ error: err instanceof Error ? err.message : "Internal server error" });
};
