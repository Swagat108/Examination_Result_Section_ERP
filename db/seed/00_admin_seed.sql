-- =====================================================================
-- seed/00_admin_seed.sql   |  G1 master data
-- Departments, programs, academic years, semesters, divisions, batches,
-- roles, business settings.
-- ASSUMPTIONS (replace with the real calendar if different):
--   * academic years run July -> June, odd term Jul-Dec, even term Jan-May
--   * semester start/end dates below are approximate
-- Divisions and batches (TY V..VIII, K5..N8) come from the E&TC roll-call PDF.
-- =====================================================================
SET NAMES utf8mb4;

INSERT INTO department (dept_code, dept_name, dept_type) VALUES
  ('ETC', 'Electronics & Telecommunication Engineering', 'ACADEMIC'),
  ('CMP', 'Computer Engineering',                        'ACADEMIC'),
  ('ITX', 'Information Technology',                      'ACADEMIC'),
  ('ADM', 'Administration & Accounts',                   'ADMINISTRATIVE');

INSERT INTO program (dept_code, program_code, program_name, degree_level, duration_years, total_semesters) VALUES
  ('ETC', 'BTECH-ETC', 'B.Tech Electronics & Telecommunication Engineering', 'UG', 4, 8),
  ('CMP', 'BTECH-CMP', 'B.Tech Computer Engineering',                        'UG', 4, 8),
  ('ITX', 'BTECH-ITX', 'B.Tech Information Technology',                      'UG', 4, 8);

INSERT INTO academic_year (label, start_date, end_date, is_current) VALUES
  ('2024-25', '2024-07-01', '2025-06-30', 0),
  ('2025-26', '2025-07-01', '2026-06-30', 0),
  ('2026-27', '2026-07-01', '2027-06-30', 1);

INSERT INTO semester (academic_year_id, term, start_date, end_date, is_active)
SELECT ay.academic_year_id, t.term, t.start_date, t.end_date, t.is_active
  FROM academic_year ay
  JOIN (SELECT '2024-25' AS label, 'ODD'  AS term, '2024-07-22' AS start_date, '2024-12-14' AS end_date, 0 AS is_active
        UNION ALL SELECT '2024-25', 'EVEN', '2025-01-06', '2025-05-17', 0
        UNION ALL SELECT '2025-26', 'ODD',  '2025-07-21', '2025-12-13', 0
        UNION ALL SELECT '2025-26', 'EVEN', '2026-01-05', '2026-05-16', 0
        UNION ALL SELECT '2026-27', 'ODD',  '2026-07-27', '2026-12-12', 1
        UNION ALL SELECT '2026-27', 'EVEN', '2027-01-04', '2027-05-15', 0) t
    ON t.label = ay.label;

-- Third-year (TY) divisions of E&TC in 2026-27, with their practical batches (K..N + division number)
INSERT INTO division (program_id, academic_year_id, year_of_study, division_name)
SELECT p.program_id, ay.academic_year_id, 3, d.division_name
  FROM program p
  JOIN academic_year ay ON ay.label = '2026-27'
  JOIN (SELECT 'TY V' AS division_name UNION ALL SELECT 'TY VI' UNION ALL SELECT 'TY VII' UNION ALL SELECT 'TY VIII') d
 WHERE p.program_code = 'BTECH-ETC';

INSERT INTO batch (division_id, batch_code)
SELECT dv.division_id, CONCAT(l.letter, m.n)
  FROM division dv
  JOIN (SELECT 'TY V' AS division_name, 5 AS n UNION ALL SELECT 'TY VI', 6 UNION ALL SELECT 'TY VII', 7 UNION ALL SELECT 'TY VIII', 8) m
    ON m.division_name = dv.division_name
  JOIN (SELECT 'K' AS letter UNION ALL SELECT 'L' UNION ALL SELECT 'M' UNION ALL SELECT 'N') l;

INSERT INTO role (role_name, description) VALUES
  ('ADMIN',             'University administrator: users, notices, dashboards, grievances'),
  ('FACULTY',           'Teaching staff: attendance, marks, leave, timetable'),
  ('STUDENT',           'Student: own profile, attendance, fees, results, placements'),
  ('ACCOUNTANT',        'Accounts section: fee collection, receipts, payroll'),
  ('PLACEMENT_OFFICER', 'Training & placement cell: drives, rounds, offers');

INSERT INTO app_setting (setting_key, setting_value, description) VALUES
  ('min_attendance_pct',         '75',    'Minimum attendance % to sit an exam / not be a defaulter'),
  ('grievance_escalation_days',  '7',     'Days after which an unresolved grievance is escalated'),
  ('dream_package_lpa',          '10.00', 'Accepting an offer at or above this package (LPA) blocks further applications');
