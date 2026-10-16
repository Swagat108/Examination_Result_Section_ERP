import cors from "cors";
import express from "express";
import morgan from "morgan";
import { isDbConfigured } from "./config/db.js";
import { env } from "./config/env.js";
import { errorHandler, notFound } from "./middleware/error.js";
import { apiRouter } from "./modules/index.js";

export const app = express();

app.use(cors({ origin: env.corsOrigin }));
app.use(express.json());
app.use(morgan("dev"));

app.get("/api/health", (_req, res) => {
  res.json({ status: "ok", database: isDbConfigured() ? "configured" : "not configured (Supabase placeholders empty)" });
});

app.use("/api", apiRouter);
app.use(notFound);
app.use(errorHandler);
