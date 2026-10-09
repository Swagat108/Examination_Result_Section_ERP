-- =====================================================================
-- seed/sample/03_attendance_sample.sql   |  G4 SYNTHETIC attendance for September 2026
-- Real student ids (from the roll call) with GENERATED attendance - not real records.
-- Skipped by `rebuild --no-sample`.
--   * a class_session for every timetable slot on every matching weekday of 2026-09-01 .. 2026-09-30
--   * student_attendance: each student gets a stable "absence rate" (2..32 %, skewed low) from a hash of
--     the student id, so a realistic ~10 % of students end below the 75 % line in some course
--   * faculty attendance + a handful of leave applications (approved through trg_leave_approval)
-- =====================================================================
SET NAMES utf8mb4;
SET @sem_cur = fn_current_semester();

-- 1. sessions
INSERT INTO class_session (offering_id, session_date, start_time, end_time, session_type, batch_id,
                           conducted_by, classroom_id, status)
WITH RECURSIVE days (d) AS (
  SELECT DATE('2026-09-01') UNION ALL SELECT d + INTERVAL 1 DAY FROM days WHERE d < DATE('2026-09-30'))
SELECT ts.offering_id, days.d, ts.start_time, ts.end_time, ts.slot_type, ts.batch_id,
       ts.employee_id, ts.classroom_id, 'HELD'
  FROM days
  JOIN timetable_slot ts ON ts.day_of_week = ELT(WEEKDAY(days.d) + 1, 'MON','TUE','WED','THU','FRI','SAT','SUN')
  JOIN course_offering o ON o.offering_id = ts.offering_id AND o.semester_id = @sem_cur
 ORDER BY days.d, ts.slot_id;

-- 2. student attendance for every enrolled student (batch sessions only for that batch)
INSERT INTO student_attendance (session_id, student_id, status, marked_by)
SELECT cs.session_id, ce.student_id,
       IF(MOD(CRC32(CONCAT(ce.student_id, '#', cs.session_id)), 100) < p.absent_pct, 'ABSENT', 'PRESENT'),
       cs.conducted_by
  FROM class_session cs
  JOIN course_offering o     ON o.offering_id = cs.offering_id
  JOIN course_enrollment ce  ON ce.offering_id = o.offering_id AND ce.status = 'ENROLLED'
  LEFT JOIN semester_registration sr ON sr.student_id = ce.student_id AND sr.semester_id = o.semester_id
  JOIN (SELECT student_id, 2 + ROUND(POW(MOD(CRC32(student_id), 100) / 100, 2.5) * 30) AS absent_pct
          FROM student) p ON p.student_id = ce.student_id
 WHERE cs.batch_id IS NULL OR sr.batch_id = cs.batch_id;

-- 3. leave applications: filed as PENDING, then decided (the trigger deducts the balance on approval)
INSERT INTO leave_application (employee_id, leave_type_id, from_date, to_date, reason, applied_on)
SELECT v.employee_id, lt.leave_type_id, v.from_date, v.to_date, v.reason, v.applied_on
  FROM leave_type lt
  JOIN (SELECT 'EMP0102' AS employee_id, 'CL' AS code, '2026-09-10' AS from_date, '2026-09-11' AS to_date, 'Family function' AS reason, '2026-09-05' AS applied_on
        UNION ALL SELECT 'EMP0104', 'ML',  '2026-09-21', '2026-09-23', 'Medical rest',         '2026-09-19'
        UNION ALL SELECT 'EMP0107', 'LWP', '2026-09-24', '2026-09-26', 'Personal work',        '2026-09-15'
        UNION ALL SELECT 'EMP0110', 'CL',  '2026-09-28', '2026-09-28', 'Personal work',        '2026-09-25'
        UNION ALL SELECT 'EMP0118', 'EL',  '2026-09-15', '2026-09-16', 'Out of station',       '2026-09-08'
        UNION ALL SELECT 'EMP0125', 'CL',  '2026-09-03', '2026-09-03', 'Bank work',            '2026-09-01') v
    ON v.code = lt.leave_code;

UPDATE leave_application SET status = 'APPROVED', decided_by = 'EMP0101', decided_on = '2026-09-08'
 WHERE employee_id = 'EMP0102' AND from_date = '2026-09-10';
UPDATE leave_application SET status = 'APPROVED', decided_by = 'EMP0101', decided_on = '2026-09-20'
 WHERE employee_id = 'EMP0104' AND from_date = '2026-09-21';
UPDATE leave_application SET status = 'APPROVED', decided_by = 'EMP0101', decided_on = '2026-09-16'
 WHERE employee_id = 'EMP0107' AND from_date = '2026-09-24';
UPDATE leave_application SET status = 'REJECTED', decided_by = 'EMP0101', decided_on = '2026-09-09', remarks = 'Exam duty that week'
 WHERE employee_id = 'EMP0118' AND from_date = '2026-09-15';
UPDATE leave_application SET status = 'APPROVED', decided_by = 'EMP0121', decided_on = '2026-09-02'
 WHERE employee_id = 'EMP0125' AND from_date = '2026-09-03';
-- EMP0110 stays PENDING

-- 4. faculty attendance on weekdays: ON_LEAVE inside an approved leave, ~2 % random absence, else PRESENT
INSERT INTO faculty_attendance (employee_id, attendance_date, status, check_in, check_out)
SELECT x.employee_id, x.d, x.status,
       IF(x.status = 'PRESENT', SEC_TO_TIME(9 * 3600 + MOD(CRC32(CONCAT(x.employee_id, x.d)), 25) * 60), NULL),
       IF(x.status = 'PRESENT', SEC_TO_TIME(17 * 3600 + MOD(CRC32(CONCAT(x.d, x.employee_id)), 45) * 60), NULL)
  FROM (WITH RECURSIVE days (d) AS (
          SELECT DATE('2026-09-01') UNION ALL SELECT d + INTERVAL 1 DAY FROM days WHERE d < DATE('2026-09-30'))
        SELECT e.employee_id, days.d,
               CASE WHEN EXISTS (SELECT 1 FROM leave_application la
                                  WHERE la.employee_id = e.employee_id AND la.status = 'APPROVED'
                                    AND days.d BETWEEN la.from_date AND la.to_date) THEN 'ON_LEAVE'
                    WHEN MOD(CRC32(CONCAT(e.employee_id, '|', days.d)), 100) < 2 THEN 'ABSENT'
                    ELSE 'PRESENT' END AS status
          FROM employee e CROSS JOIN days
         WHERE e.status = 'ACTIVE' AND WEEKDAY(days.d) < 5) x;
