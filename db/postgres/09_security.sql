-- Supabase hardening. Not part of the MySQL original.
-- Supabase exposes everything in `public` through its REST API to the `anon` / `authenticated` roles.
-- This ERP is accessed only through the Express backend (service_role key), so:
--   * row level security is switched on for every table (no policies = deny for anon / authenticated;
--     service_role and the table owner bypass RLS)
--   * anon / authenticated lose all table, view and function privileges, today and for future objects
-- Add explicit policies + grants later if the frontend ever talks to Supabase directly.
DO $$
DECLARE r record;
BEGIN
  FOR r IN SELECT tablename FROM pg_tables WHERE schemaname = 'public' LOOP
    EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', r.tablename);
  END LOOP;

  FOR r IN SELECT rolname FROM pg_roles WHERE rolname IN ('anon', 'authenticated') LOOP
    EXECUTE format('REVOKE ALL ON ALL TABLES    IN SCHEMA public FROM %I', r.rolname);
    EXECUTE format('REVOKE ALL ON ALL SEQUENCES IN SCHEMA public FROM %I', r.rolname);
    EXECUTE format('REVOKE ALL ON ALL FUNCTIONS IN SCHEMA public FROM %I', r.rolname);
    EXECUTE format('ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE ALL ON TABLES    FROM %I', r.rolname);
    EXECUTE format('ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE ALL ON SEQUENCES FROM %I', r.rolname);
    EXECUTE format('ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE ALL ON FUNCTIONS FROM %I', r.rolname);
  END LOOP;
END;
$$;
-- Functions are executable by PUBLIC by default, which includes anon / authenticated.
REVOKE EXECUTE ON ALL FUNCTIONS IN SCHEMA public FROM PUBLIC;
ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC;
