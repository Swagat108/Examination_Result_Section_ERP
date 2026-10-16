-- PostgreSQL port helper for db/seed/sample/*.sql. MySQL's CRC32() has no PostgreSQL equivalent, so the
-- synthetic data is driven by this stable hash instead (same student -> same value on every run).
-- Lives in the session's pg_temp schema: nothing is left behind in the database.
CREATE FUNCTION pg_temp.seed_hash(t TEXT) RETURNS BIGINT
LANGUAGE sql IMMUTABLE AS $$ SELECT hashtextextended(t, 0) & 2147483647 $$;
