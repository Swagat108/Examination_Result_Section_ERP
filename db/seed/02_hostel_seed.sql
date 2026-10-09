-- =====================================================================
-- seed/02_hostel_seed.sql   |  G6 hostel blocks and rooms (SAMPLE)
-- 3 hostels x 4 floors x 10 rooms. Boys' rooms sleep 3, girls' rooms 2.
-- No allocations are seeded: gender is not in the roll-call PDF, so beds are
-- filled through trg_room_allocation_beds (demo step 3 / tests).
-- =====================================================================
SET NAMES utf8mb4;

INSERT INTO hostel (hostel_code, hostel_name, hostel_type) VALUES
  ('BH1', 'Boys Hostel 1',  'BOYS'),
  ('BH2', 'Boys Hostel 2',  'BOYS'),
  ('GH1', 'Girls Hostel 1', 'GIRLS');

INSERT INTO room (room_code, hostel_id, floor_no, capacity, available_beds)
WITH RECURSIVE n (i) AS (SELECT 1 UNION ALL SELECT i + 1 FROM n WHERE i < 10)
SELECT CONCAT(h.hostel_code, '-', f.floor_no, LPAD(n.i, 2, '0')),
       h.hostel_id, f.floor_no,
       IF(h.hostel_type = 'BOYS', 3, 2), IF(h.hostel_type = 'BOYS', 3, 2)
  FROM hostel h
  JOIN (SELECT 1 AS floor_no UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4) f
  JOIN n;
