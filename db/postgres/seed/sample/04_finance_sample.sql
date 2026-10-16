-- PostgreSQL port of db/seed/sample/04_finance_sample.sql  |  G5 SYNTHETIC payments, scholarships, September payroll
-- Real student ids with GENERATED payment behaviour - not real records. Skipped by --no-sample.
--   hash bucket 0-69  : pays every invoice in full            (~70 %)
--   hash bucket 70-84 : pays half the tuition + development, library, lab; exam fee still unpaid (~15 %)
--   hash bucket 85-99 : pays nothing -> shows up in vw_fee_defaulters (~15 %)
-- Payments fall on 28 Jul .. 27 Aug 2026 (before the 31 Aug due date), so no late fee was charged.
INSERT INTO fee_payment (invoice_id, amount, payment_mode, transaction_ref, paid_on, late_fee_charged)
SELECT t.invoice_id,
       CASE WHEN t.bucket < 70 THEN t.payable ELSE ROUND(t.payable / 2, 2) END,
       (ARRAY['UPI', 'CARD', 'NET_BANKING', 'CASH'])[1 + MOD(pg_temp.seed_hash(CONCAT('mode', t.invoice_id)), 4)::INT],
       CONCAT('TXN', LPAD(t.invoice_id::TEXT, 8, '0')),
       TIMESTAMP '2026-07-28 10:00:00' + MOD(pg_temp.seed_hash(t.student_id), 30)::INT * INTERVAL '1 day'
                                        + MOD(t.invoice_id, 480) * INTERVAL '1 minute',
       0
  FROM (SELECT fi.invoice_id, fi.student_id, fi.amount - fi.discount AS payable, fs.fee_type,
               MOD(pg_temp.seed_hash(fi.student_id), 100) AS bucket
          FROM fee_invoice fi JOIN fee_structure fs ON fs.fee_structure_id = fi.fee_structure_id) t
 WHERE t.bucket < 70
    OR (t.bucket < 85 AND t.fee_type <> 'EXAM')
 ORDER BY t.invoice_id;

UPDATE fee_invoice fi
   SET amount_paid = p.paid,
       status = CASE WHEN p.paid >= fi.amount - fi.discount + fi.late_fee THEN 'PAID' ELSE 'PARTIALLY_PAID' END
  FROM (SELECT invoice_id, SUM(amount) AS paid FROM fee_payment GROUP BY invoice_id) p
 WHERE p.invoice_id = fi.invoice_id;

-- receipts, numbered like sp_process_fee_payment does (RCP-<year>-<serial>), counter brought up to date
INSERT INTO fee_receipt (receipt_no, payment_id, issued_on)
SELECT CONCAT('RCP-2026-', LPAD((ROW_NUMBER() OVER (ORDER BY paid_on, payment_id))::TEXT, 6, '0')), payment_id, paid_on
  FROM fee_payment;
INSERT INTO receipt_counter (receipt_year, last_no) VALUES (2026, (SELECT COUNT(*) FROM fee_receipt))
  ON CONFLICT (receipt_year) DO UPDATE SET last_no = EXCLUDED.last_no;

-- a few scholarships (~2 % of students)
INSERT INTO scholarship (student_id, academic_year_id, scholarship_name, provider, amount, status, decided_on)
SELECT s.student_id, ay.academic_year_id, 'Merit Scholarship (sample)', 'University', 25000.00, 'APPROVED', '2026-08-10'
  FROM student s JOIN academic_year ay ON ay.label = '2026-27'
 WHERE MOD(pg_temp.seed_hash(CONCAT(s.student_id, 'sch')), 50) = 0;

-- September payroll; EMP0107's approved unpaid leave (24-26 Sep) is deducted as loss of pay
SELECT sp_calculate_monthly_payroll(9, 2026);
