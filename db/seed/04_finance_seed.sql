-- =====================================================================
-- seed/04_finance_seed.sql   |  G5 fee structures, salary structures, invoices
-- ASSUMED AMOUNTS (replace with the real fee schedule): tuition 90,000 + 5,000 per year of study,
-- development 5,000, library 2,000, lab 6,000, exam 3,500, hostel 55,000. Late fee: 50/day on tuition, 10/day elsewhere.
-- Invoices are produced by sp_generate_fee_invoices for every registered TY E&TC student (no hostel invoice
-- unless the student holds a bed). Payments are in seed/sample/04_finance_sample.sql.
-- =====================================================================
SET NAMES utf8mb4;

INSERT INTO fee_structure (program_id, academic_year_id, year_of_study, fee_type, amount, late_fee_per_day, due_date)
SELECT p.program_id, ay.academic_year_id, y.n, f.fee_type, f.base + (y.n - 1) * f.step, f.late_fee, f.due_date
  FROM program p
  JOIN academic_year ay ON ay.label = '2026-27'
  JOIN (SELECT 1 AS n UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4) y
  JOIN (SELECT 'TUITION'     AS fee_type, 90000.00 AS base, 5000.00 AS step, 50.00 AS late_fee, '2026-08-31' AS due_date
        UNION ALL SELECT 'DEVELOPMENT',  5000.00, 0.00, 10.00, '2026-08-31'
        UNION ALL SELECT 'LIBRARY',      2000.00, 0.00, 10.00, '2026-08-31'
        UNION ALL SELECT 'LAB',          6000.00, 0.00, 10.00, '2026-08-31'
        UNION ALL SELECT 'EXAM',         3500.00, 0.00, 10.00, '2026-10-31'
        UNION ALL SELECT 'HOSTEL',      55000.00, 0.00, 50.00, '2026-08-31') f;

-- Salary: base by designation (+ small spread by employee number). DA 40 %, HRA 20 %, PF 12 %, PT 200.
INSERT INTO salary_structure (employee_id, effective_from, basic_pay, da_pct, hra_pct, other_allowance, pf_pct, professional_tax)
SELECT e.employee_id, '2026-04-01',
       CASE d.designation_name
         WHEN 'Professor'                    THEN 160000
         WHEN 'Associate Professor'          THEN 130000
         WHEN 'Assistant Professor'          THEN  90000
         WHEN 'Administrative Officer'       THEN  80000
         WHEN 'Training & Placement Officer' THEN  70000
         ELSE                                     55000
       END + MOD(CAST(SUBSTRING(e.employee_id, 4) AS UNSIGNED), 7) * 1000,
       40.00, 20.00, 3000.00, 12.00, 200.00
  FROM employee e JOIN designation d ON d.designation_id = e.designation_id;

SET @prog = (SELECT program_id FROM program WHERE program_code = 'BTECH-ETC');
SET @ay   = (SELECT academic_year_id FROM academic_year WHERE label = '2026-27');
CALL sp_generate_fee_invoices(@prog, @ay, 3);
