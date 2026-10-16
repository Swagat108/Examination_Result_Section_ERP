-- After seeding: move every identity sequence past the highest existing id, so the next INSERT
-- without an explicit id never collides with seeded rows.
DO $$
DECLARE r record;
BEGIN
  FOR r IN
    SELECT c.table_name, c.column_name,
           pg_get_serial_sequence(format('public.%I', c.table_name), c.column_name) AS seq
      FROM information_schema.columns c
     WHERE c.table_schema = 'public' AND c.is_identity = 'YES'
  LOOP
    IF r.seq IS NOT NULL THEN
      EXECUTE format('SELECT setval(%L, COALESCE((SELECT MAX(%I) FROM public.%I), 0) + 1, false)',
                     r.seq, r.column_name, r.table_name);
    END IF;
  END LOOP;
END;
$$;
