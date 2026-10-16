// Applies the PostgreSQL scripts in db/postgres/ to the database in DATABASE_URL (Supabase).
//
//   npm run db:migrate                  schema + objects + core seed + sample data
//   npm run db:migrate -- --no-sample   skip the synthetic sample data (attendance, payments, marks, ...)
//   npm run db:migrate -- --no-seed     schema + objects only
//   npm run db:migrate -- --reset       FIRST drops every table/view/function in `public`, then migrates
//
// Order: all *_tables.sql -> 07_integration_tables.sql -> *_objects.sql -> 08_updated_at_triggers.sql
//        -> 09_security.sql -> seed (see seed/seed_order.txt) -> 09_post_seed.sql
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import dotenv from "dotenv";
import pg from "pg";

const here = path.dirname(fileURLToPath(import.meta.url));
dotenv.config({ path: path.resolve(here, "../../.env") });

const args = new Set(process.argv.slice(2));
const url = process.env.DATABASE_URL;
if (!url) {
  console.error("DATABASE_URL is empty. Fill it in .env (Supabase > Project Settings > Database).");
  process.exit(1);
}

const modules = ["00_admin", "01_academics", "02_students", "03_attendance", "04_finance", "05_exams", "06_placement"];
const steps = [
  ...modules.map((m) => `${m}_tables.sql`),
  "07_integration_tables.sql",
  ...modules.map((m) => `${m}_objects.sql`),
  "07_integration_objects.sql",
  "08_updated_at_triggers.sql",
  "09_security.sql",
];

const client = new pg.Client({ connectionString: url, ssl: { rejectUnauthorized: false } });
await client.connect();

async function runFile(rel) {
  const sql = fs.readFileSync(path.join(here, rel), "utf8");
  process.stdout.write(`  ${rel} ... `);
  try {
    await client.query("BEGIN");
    await client.query(sql);
    await client.query("COMMIT");
    console.log("ok");
  } catch (e) {
    await client.query("ROLLBACK").catch(() => {});
    console.log("FAILED");
    console.error(`    ${e.message}${e.position ? ` (char ${e.position})` : ""}${e.where ? `\n    ${e.where.split("\n")[0]}` : ""}`);
    await client.end();
    process.exit(1);
  }
}

if (args.has("--reset")) {
  console.log("==> reset: dropping all objects in schema public");
  await client.query(`
    DO $$ DECLARE r record; BEGIN
      FOR r IN SELECT viewname FROM pg_views WHERE schemaname = 'public' LOOP
        EXECUTE format('DROP VIEW IF EXISTS public.%I CASCADE', r.viewname); END LOOP;
      FOR r IN SELECT tablename FROM pg_tables WHERE schemaname = 'public' LOOP
        EXECUTE format('DROP TABLE IF EXISTS public.%I CASCADE', r.tablename); END LOOP;
      FOR r IN SELECT p.oid::regprocedure AS sig FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
               WHERE n.nspname = 'public' AND NOT EXISTS (SELECT 1 FROM pg_depend d WHERE d.objid = p.oid AND d.deptype = 'e') LOOP
        EXECUTE format('DROP ROUTINE IF EXISTS %s CASCADE', r.sig); END LOOP;
    END $$;`);
}

console.log("==> schema + SQL objects");
for (const s of steps) await runFile(s);

if (!args.has("--no-seed")) {
  console.log("==> seed data");
  const order = fs.readFileSync(path.join(here, "seed/seed_order.txt"), "utf8").split(/\r?\n/);
  for (const line of order) {
    if (!line.trim() || line.startsWith("#")) continue;
    const [kind, rel] = line.trim().split(/\s+/);
    if (kind === "sample" && args.has("--no-sample")) continue;
    await runFile(rel);
  }
  console.log("==> post-seed");
  await runFile("09_post_seed.sql");
}

await client.end();
console.log("done");
