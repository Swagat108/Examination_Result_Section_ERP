-- =====================================================================
-- seed/sample/05_exams_sample.sql   |  G2 SYNTHETIC semester-4 results (exam EX-2026-S4-01)
-- Real student ids with GENERATED marks - not real results. Skipped by `rebuild --no-sample`.
-- Every E&TC student is registered for all six semester-4 papers (no attendance data exists for that
-- finished term, so the 75 % trigger lets everyone through). Marks = a stable per-student ability
-- (45..94) +/- 8 per course, capped at 100, with ~0.3 % absentees. Then sp_publish_results fills `result`,
-- which feeds fn_calculate_cgpa, vw_rank_list and the placement eligibility check.
-- =====================================================================
SET NAMES utf8mb4;

INSERT INTO exam_registration (exam_id, student_id, offering_id, registered_on)
SELECT es.exam_id, s.student_id, es.offering_id, '2026-04-15 10:00:00'
  FROM student s
  JOIN exam_schedule es ON es.exam_id = 'EX-2026-S4-01'
 ORDER BY s.student_id, es.offering_id;

INSERT INTO marks (exam_id, student_id, offering_id, marks_obtained, is_absent, entered_by)
SELECT m.exam_id, m.student_id, m.offering_id,
       IF(m.is_absent = 1, NULL, LEAST(es.max_marks, GREATEST(18, ROUND(m.pct * es.max_marks / 100)))),
       m.is_absent, o.employee_id
  FROM (SELECT r.exam_id, r.student_id, r.offering_id,
               MOD(CRC32(CONCAT(r.student_id, 'abs', r.offering_id)), 1000) < 3 AS is_absent,
               45 + MOD(CRC32(r.student_id), 50) + MOD(CRC32(CONCAT(r.student_id, '#', r.offering_id)), 17) - 8 AS pct
          FROM exam_registration r WHERE r.exam_id = 'EX-2026-S4-01') m
  JOIN exam_schedule es ON es.exam_id = m.exam_id AND es.offering_id = m.offering_id
  JOIN course_offering o ON o.offering_id = m.offering_id;

CALL sp_publish_results('EX-2026-S4-01');
