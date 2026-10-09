-- =====================================================================
-- seed/03_attendance_seed.sql   |  G4 leave policy
-- Quotas are assumed (CL 12, EL 30, ML 10 per calendar year); LWP is unpaid with no quota.
-- =====================================================================
SET NAMES utf8mb4;

INSERT INTO leave_type (leave_code, leave_name, annual_quota, is_paid) VALUES
  ('CL',  'Casual Leave',       12.0, 1),
  ('EL',  'Earned Leave',       30.0, 1),
  ('ML',  'Medical Leave',      10.0, 1),
  ('LWP', 'Leave Without Pay',  NULL, 0);

INSERT INTO leave_balance (employee_id, leave_type_id, leave_year, allocated)
SELECT e.employee_id, lt.leave_type_id, 2026, lt.annual_quota
  FROM employee e
  JOIN leave_type lt ON lt.annual_quota IS NOT NULL
 WHERE e.status = 'ACTIVE';
