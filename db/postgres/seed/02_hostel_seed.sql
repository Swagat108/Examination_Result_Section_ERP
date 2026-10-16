-- PostgreSQL port of db/seed/02_hostel_seed.sql. MySQL original is unchanged.
-- =====================================================================
-- seed/02_hostel_seed.sql   |  G6 hostel blocks and rooms (SAMPLE)
-- 3 hostels x 4 floors x 10 rooms. Boys' rooms sleep 3, girls' rooms 2.
-- No allocations are seeded: gender is not in the roll-call PDF, so beds are
-- filled through trg_room_allocation_beds (demo step 3 / tests).
-- =====================================================================

INSERT INTO hostel (hostel_code, hostel_name, hostel_type) VALUES
  ('BH1', 'Boys Hostel 1',  'BOYS'),
  ('BH2', 'Boys Hostel 2',  'BOYS'),
  ('GH1', 'Girls Hostel 1', 'GIRLS');

WITH RECURSIVE n (i) AS (SELECT 1 UNION ALL SELECT i + 1 FROM n WHERE i < 10)
INSERT INTO room (room_code, hostel_id, floor_no, capacity, available_beds)
SELECT CONCAT(h.hostel_code, '-', f.floor_no, LPAD(n.i::TEXT, 2, '0')),
       h.hostel_id, f.floor_no,
       CASE WHEN h.hostel_type = 'BOYS' THEN 3 ELSE 2 END, CASE WHEN h.hostel_type = 'BOYS' THEN 3 ELSE 2 END
  FROM hostel h
  CROSS JOIN (SELECT 1 AS floor_no UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4) f
  CROSS JOIN n;
