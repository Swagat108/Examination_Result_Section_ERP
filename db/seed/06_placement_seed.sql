-- =====================================================================
-- seed/06_placement_seed.sql   |  G7 companies, drives, rounds (SAMPLE, fictional recruiters)
-- 15 companies, 8 drives with different eligibility rules, 3 rounds per drive (the last is final).
-- No applications or offers are seeded: they are created live by sp_register_for_drive /
-- sp_record_round_result (demo step 9 and the tests).
-- =====================================================================
SET NAMES utf8mb4;

INSERT INTO company (company_name, industry, city) VALUES
  ('Axion Semiconductors',          'Semiconductors',          'Bengaluru'),
  ('Vertex Telecom Systems',        'Telecom',                 'Pune'),
  ('Nimbus Cloud Labs',             'Cloud Services',          'Hyderabad'),
  ('Orion Embedded Technologies',   'Embedded Systems',        'Pune'),
  ('Helix Networks',                'Networking',              'Bengaluru'),
  ('Quanta Analytics',              'Data Analytics',          'Mumbai'),
  ('Zenith Software Services',      'IT Services',             'Pune'),
  ('Pioneer Automation',            'Industrial Automation',   'Nashik'),
  ('Lumen Optics',                  'Photonics',               'Chennai'),
  ('Aurora Robotics',               'Robotics',                'Pune'),
  ('Stratus FinTech',               'FinTech',                 'Mumbai'),
  ('Cobalt Power Electronics',      'Power Electronics',       'Ahmedabad'),
  ('Meridian Consulting',           'Consulting',              'Gurugram'),
  ('Pulse Medical Devices',         'Medical Electronics',     'Bengaluru'),
  ('Vector Mobility',               'Automotive Electronics',  'Pune');

INSERT INTO placement_drive (drive_id, company_id, academic_year_id, job_role, job_type, package_lpa, min_cgpa,
                             max_backlogs, drive_date, registration_deadline, location, status)
SELECT d.drive_id, c.company_id, ay.academic_year_id, d.job_role, d.job_type, d.package_lpa, d.min_cgpa,
       d.max_backlogs, d.drive_date, d.registration_deadline, d.location, d.status
  FROM academic_year ay
  JOIN (
    SELECT 'DRV-2026-001' AS drive_id, 'Axion Semiconductors' AS company_name, 'Design Verification Engineer' AS job_role, 'FULL_TIME' AS job_type, 12.00 AS package_lpa, 7.50 AS min_cgpa, 0 AS max_backlogs, '2026-11-18' AS drive_date, '2026-11-10' AS registration_deadline, 'Bengaluru' AS location, 'OPEN' AS status
    UNION ALL SELECT 'DRV-2026-002', 'Vertex Telecom Systems',      'Network Engineer',             'FULL_TIME',      6.50, 6.50, 1, '2026-11-05', '2026-11-01', 'Pune',      'OPEN'
    UNION ALL SELECT 'DRV-2026-003', 'Nimbus Cloud Labs',           'Cloud Support Engineer',       'FULL_TIME',      8.00, 7.00, 0, '2026-11-25', '2026-11-15', 'Hyderabad', 'OPEN'
    UNION ALL SELECT 'DRV-2026-004', 'Orion Embedded Technologies', 'Embedded Software Engineer',   'FULL_TIME',      7.20, 6.50, 0, '2026-12-02', '2026-11-25', 'Pune',      'UPCOMING'
    UNION ALL SELECT 'DRV-2026-005', 'Zenith Software Services',    'Associate Software Engineer',  'FULL_TIME',      4.50, 6.00, 2, '2026-10-20', '2026-10-15', 'Pune',      'OPEN'
    UNION ALL SELECT 'DRV-2026-006', 'Quanta Analytics',            'Data Analyst',                 'FULL_TIME',      9.00, 7.00, 0, '2026-12-10', '2026-12-01', 'Mumbai',    'UPCOMING'
    UNION ALL SELECT 'DRV-2026-007', 'Aurora Robotics',             'Robotics Intern (PPO)',        'INTERNSHIP_PPO', 5.00, 7.00, 0, '2026-09-20', '2026-09-15', 'Pune',      'COMPLETED'
    UNION ALL SELECT 'DRV-2026-008', 'Stratus FinTech',             'Software Engineer',            'FULL_TIME',     18.00, 8.50, 0, '2026-11-30', '2026-11-20', 'Mumbai',    'OPEN'
  ) d
  JOIN company c ON c.company_name = d.company_name
 WHERE ay.label = '2026-27';

INSERT INTO drive_eligible_branch (drive_id, dept_code) VALUES
  ('DRV-2026-001', 'ETC'),
  ('DRV-2026-002', 'ETC'), ('DRV-2026-002', 'ITX'),
  ('DRV-2026-003', 'ETC'), ('DRV-2026-003', 'CMP'), ('DRV-2026-003', 'ITX'),
  ('DRV-2026-004', 'ETC'),
  ('DRV-2026-005', 'ETC'), ('DRV-2026-005', 'CMP'), ('DRV-2026-005', 'ITX'),
  ('DRV-2026-006', 'ETC'), ('DRV-2026-006', 'CMP'), ('DRV-2026-006', 'ITX'),
  ('DRV-2026-007', 'ETC'),
  ('DRV-2026-008', 'ETC'), ('DRV-2026-008', 'CMP'), ('DRV-2026-008', 'ITX');

INSERT INTO interview_round (drive_id, round_no, round_name, round_type, is_final)
SELECT d.drive_id, r.round_no, r.round_name, r.round_type, r.is_final
  FROM placement_drive d
  JOIN (SELECT 1 AS round_no, 'Online Aptitude Test' AS round_name, 'APTITUDE'  AS round_type, 0 AS is_final
        UNION ALL SELECT 2, 'Technical Interview', 'TECHNICAL', 0
        UNION ALL SELECT 3, 'HR Interview',        'HR',        1) r;
