import dotenv from "dotenv";

// npm workspaces run with cwd=backend/, so also look at the repo-root .env
dotenv.config({ path: "../.env" });
dotenv.config();

const required = (name: string, fallback?: string): string => {
  const value = process.env[name] ?? fallback;
  if (value === undefined) throw new Error(`Missing env var ${name}`);
  return value;
};

export const env = {
  port: Number(process.env.PORT ?? 4000),
  corsOrigin: process.env.CORS_ORIGIN ?? "http://localhost:5173",
  jwtSecret: required("JWT_SECRET", "dev-only-change-me"),
  jwtExpiresIn: process.env.JWT_EXPIRES_IN ?? "8h",
  bcryptRounds: Number(process.env.BCRYPT_ROUNDS ?? 10),
  // Supabase placeholders: empty until the team provisions the project.
  supabaseUrl: process.env.SUPABASE_URL ?? "",
  supabaseAnonKey: process.env.SUPABASE_ANON_KEY ?? "",
  supabaseServiceRoleKey: process.env.SUPABASE_SERVICE_ROLE_KEY ?? "",
  databaseUrl: process.env.DATABASE_URL ?? "",
};
