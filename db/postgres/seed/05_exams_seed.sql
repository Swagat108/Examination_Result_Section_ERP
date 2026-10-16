-- PostgreSQL port of db/seed/05_exams_seed.sql. MySQL original is unchanged.
-- =====================================================================
-- seed/05_exams_seed.sql   |  G2 grade scale, exams and their schedules
--   EX-2026-S4-01  semester 4, held April-May 2026 (history used by the CGPA / rank list)
--   EX-2026-S5-01  semester 5, Nov-Dec 2026, registration open (demo step 6)
-- Dates and the 10-point grade scale are ASSUMED; weekdays only.
-- =====================================================================

INSERT INTO grade_scale (grade, min_pct, grade_point, is_pass, description) VALUES
  ('O',  90.00, 10.0, 1, 'Outstanding'),
  ('A+', 80.00,  9.0, 1, 'Excellent'),
  ('A',  70.00,  8.0, 1, 'Very good'),
  ('B+', 60.00,  7.0, 1, 'Good'),
  ('B',  55.00,  6.0, 1, 'Above average'),
  ('C',  50.00,  5.0, 1, 'Average'),
  ('P',  40.00,  4.0, 1, 'Pass'),
  ('F',   0.00,  0.0, 0, 'Fail');

SELECT set_config('seed.sem_cur', (fn_current_semester())::TEXT, false);
SELECT set_config('seed.sem_prev', ((SELECT s.semester_id FROM semester s JOIN academic_year ay ON ay.academic_year_id = s.academic_year_id
                  WHERE ay.label = '2025-26' AND s.term = 'EVEN'))::TEXT, false);

INSERT INTO exam (exam_id, exam_name, exam_type, semester_id, sem_no, registration_deadline, start_date, end_date, status) VALUES
  ('EX-2026-S4-01', 'End Semester Examination - Semester IV (2025-26)', 'ESE', current_setting('seed.sem_prev')::INTEGER, 4, '2026-04-15', '2026-04-27', '2026-05-15', 'COMPLETED'),
  ('EX-2026-S5-01', 'End Semester Examination - Semester V (2026-27)',  'ESE', current_setting('seed.sem_cur')::INTEGER,  5, '2026-11-10', '2026-11-23', '2026-12-11', 'REGISTRATION_OPEN');

-- One paper per E&TC offering, one day per distinct course code (all divisions of a course sit together).
-- Theory 100 marks (pass 40), lab 50 marks (pass 20); 10:00-13:00.
INSERT INTO exam_schedule (exam_id, offering_id, exam_date, start_time, end_time, max_marks, passing_marks)
SELECT x.exam_id, x.offering_id,
       x.start_date + ((x.rk - 1) + 2 * ((x.rk - 1) / 5))::INTEGER,
       '10:00:00', '13:00:00',
       CASE WHEN x.course_type = 'THEORY' THEN 100 ELSE 50 END, CASE WHEN x.course_type = 'THEORY' THEN 40 ELSE 20 END
  FROM (SELECT e.exam_id, e.start_date, o.offering_id, c.course_type,
               DENSE_RANK() OVER (PARTITION BY e.exam_id ORDER BY o.course_code) AS rk
          FROM exam e
          JOIN course_offering o ON o.semester_id = e.semester_id
          JOIN course c          ON c.course_code = o.course_code
          JOIN curriculum cu     ON cu.course_code = o.course_code AND cu.sem_no = e.sem_no
          JOIN program p         ON p.program_id = cu.program_id AND p.program_code = 'BTECH-ETC') x;
