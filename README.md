# DBMS_PBL_ACTIVITY - University ERP
# Deadline : 24/10/2026

7 modules, one shared codebase: **React + TypeScript** frontend, **Express + TypeScript** backend, SQL in `db/`, database hosted on **Supabase** (placeholders only for now).

## Quick start

Requires Node 20+.

```bash
npm install                 # installs backend + frontend (npm workspaces)
cp .env.example .env        # fill in later; the app runs without DB values
npm run dev                 # API on :4000, web on :5173
```

Open http://localhost:5173 and sign in with a dev account (password `password123`):
`admin`, `faculty`, `student`, `accountant`, `placement`.

Other scripts: `npm run dev:api`, `npm run dev:web`, `npm run typecheck`, `npm run build`.

## Layout

```
db/                        SQL scripts, seeds (unchanged), rebuild scripts
backend/src/
  app.ts, index.ts         Express app + entry
  config/env.ts            env loading (reads root .env)
  config/db.ts             Supabase client - db().rpc("sp_x") / db().from("vw_x")
  middleware/              auth (JWT), rbac (requireRole), error handling
  modules/<module>/routes.ts   one folder per group; registered in modules/index.ts
  modules/auth.routes.ts   login (DEV accounts for now - G1 swaps in app_user)
frontend/src/
  modules.ts               sidebar + route registry with allowed roles
  pages/<module>/          one folder per group
  components/              DataTable, ModulePage (shared building blocks)
  auth/, layouts/, lib/    auth context, app shell, api helper
docs/                      ER diagrams, evidence, report
```

## Who works where

| Group | Module | Backend folder | Frontend folder |
| --- | --- | --- | --- |
| G1 | Communication & Admin | `backend/src/modules/admin` (+ `auth.routes.ts`, `middleware/`) | `frontend/src/pages/admin`, `layouts/`, `auth/` |
| G2 | Examinations | `.../exams` | `.../pages/exams` |
| G3 | Academics | `.../academics` | `.../pages/academics` |
| G4 | Attendance | `.../attendance` | `.../pages/attendance` |
| G5 | Fees & Finance | `.../finance` | `.../pages/finance` |
| G6 | Students | `.../students` | `.../pages/students` |
| G7 | Placement | `.../placement` | `.../pages/placement` |

Stay inside your own module folders to avoid merge conflicts. Shared files (`modules.ts`, `modules/index.ts`, `App.tsx`, `middleware/`) change only through a PR reviewed by Pushkaraj or Vedant.

## Adding an endpoint

```ts
// backend/src/modules/finance/routes.ts
financeRouter.post("/pay", requireRole("ACCOUNTANT"), asyncHandler(async (req, res) => {
  const { data, error } = await db().rpc("sp_process_fee_payment", req.body);
  if (error) throw new HttpError(400, error.message);
  res.json(data);
}));
```

Every module router already applies `requireAuth`. Use `requireRole(...)` per route. The current handlers return sample data so every screen works before the SQL is ready.

## Database

- `db/*.sql` and `db/seed/` are unchanged (MySQL 8.0 syntax). Run order and rebuild scripts: `db/rebuild.sh` / `db/rebuild.ps1`.
- The backend talks to **Supabase** through `backend/src/config/db.ts`. Fill these in `.env` once the project exists (see `.env.example`): `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY`, `DATABASE_URL`.
- Until they are set, `/api/health` reports the database as not configured and `db()` throws a clear error.
- Supabase runs PostgreSQL, so the MySQL scripts will need a port when the team migrates. That is a separate task.

## Git workflow

- Branch per feature: `feature-<n>/<short-name>`; open a PR into `main`.
- Reference the GitHub issue number in commits. Pushkaraj or Vedant review and merge.
