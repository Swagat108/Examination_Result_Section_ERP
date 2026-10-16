-- PostgreSQL port of db/04_finance.sql (functions, procedures, triggers, views). MySQL original is unchanged.
-- See 00_admin_objects.sql for the porting conventions.

-- Late fee on an invoice if it were paid on p_pay_date: whole days after the due date x the head's per-day rate.
CREATE FUNCTION fn_late_fee(p_invoice_id INTEGER, p_pay_date DATE) RETURNS NUMERIC(10,2)
LANGUAGE plpgsql STABLE AS $$
DECLARE
  v_due  DATE;
  v_rate NUMERIC(6,2);
BEGIN
  SELECT i.due_date, fs.late_fee_per_day INTO v_due, v_rate
    FROM fee_invoice i JOIN fee_structure fs ON fs.fee_structure_id = i.fee_structure_id
   WHERE i.invoice_id = p_invoice_id;
  IF v_due IS NULL THEN
    RETURN NULL;
  END IF;
  RETURN GREATEST(p_pay_date - v_due, 0) * v_rate;
END;
$$;

-- Outstanding amount of a student (optionally one fee type, optionally only overdue invoices).
CREATE FUNCTION fn_student_fee_due(p_student_id CHAR, p_fee_type VARCHAR DEFAULT NULL, p_overdue_only INTEGER DEFAULT 0)
RETURNS NUMERIC(10,2)
LANGUAGE sql STABLE AS $$
  SELECT COALESCE(SUM(i.balance), 0)::NUMERIC(10,2)
    FROM fee_invoice i JOIN fee_structure fs ON fs.fee_structure_id = i.fee_structure_id
   WHERE i.student_id = p_student_id
     AND i.status IN ('UNPAID','PARTIALLY_PAID')
     AND (p_fee_type IS NULL OR fs.fee_type = p_fee_type)
     AND (COALESCE(p_overdue_only, 0) = 0 OR i.due_date < CURRENT_DATE);
$$;

-- Creates invoices for every active student of a program who is in a given year of study during an
-- academic year (derived from semester_registration). HOSTEL fees only for students holding a bed.
-- Returns the number of invoices created.
CREATE FUNCTION sp_generate_fee_invoices(p_program_id INTEGER, p_academic_year_id INTEGER, p_year_of_study INTEGER)
RETURNS INTEGER
LANGUAGE plpgsql AS $$
DECLARE v_created INTEGER := 0;
BEGIN
  INSERT INTO fee_invoice (student_id, fee_structure_id, amount, due_date)
  SELECT DISTINCT sr.student_id, fs.fee_structure_id, fs.amount, fs.due_date
    FROM fee_structure fs
    JOIN semester sm ON sm.academic_year_id = fs.academic_year_id
    JOIN semester_registration sr ON sr.semester_id = sm.semester_id AND sr.status = 'REGISTERED'
                                 AND CEIL(sr.sem_no / 2.0) = fs.year_of_study
    JOIN student s ON s.student_id = sr.student_id AND s.program_id = fs.program_id AND s.status = 'ACTIVE'
   WHERE fs.program_id = p_program_id AND fs.academic_year_id = p_academic_year_id
     AND fs.year_of_study = p_year_of_study
     AND (fs.fee_type <> 'HOSTEL'
          OR EXISTS (SELECT 1 FROM room_allocation ra WHERE ra.student_id = s.student_id AND ra.status = 'ACTIVE'))
     AND NOT EXISTS (SELECT 1 FROM fee_invoice fi
                      WHERE fi.student_id = sr.student_id AND fi.fee_structure_id = fs.fee_structure_id);
  GET DIAGNOSTICS v_created = ROW_COUNT;
  RETURN v_created;
END;
$$;

-- Pays (part of) an invoice in ONE transaction: late fee is brought up to date, the payment is
-- stored, the invoice balance/status updated and a receipt number (RCP-YYYY-NNNNNN) issued and returned.
CREATE FUNCTION sp_process_fee_payment(p_invoice_id INTEGER, p_amount NUMERIC, p_mode VARCHAR)
RETURNS VARCHAR
LANGUAGE plpgsql AS $$
DECLARE
  v_amount      NUMERIC(10,2);
  v_discount    NUMERIC(10,2);
  v_late        NUMERIC(10,2);
  v_paid        NUMERIC(10,2);
  v_status      VARCHAR(15);
  v_late_now    NUMERIC(10,2);
  v_late_delta  NUMERIC(10,2);
  v_outstanding NUMERIC(10,2);
  v_new_paid    NUMERIC(10,2);
  v_pay_id      INTEGER;
  v_no          INTEGER;
  v_receipt_no  VARCHAR(16);
BEGIN
  IF p_amount IS NULL OR p_amount <= 0 THEN
    RAISE EXCEPTION 'Payment amount must be positive' USING ERRCODE = '45000';
  END IF;

  SELECT i.amount, i.discount, i.late_fee, i.amount_paid, i.status
    INTO v_amount, v_discount, v_late, v_paid, v_status
    FROM fee_invoice i WHERE i.invoice_id = p_invoice_id FOR UPDATE;
  IF v_status IS NULL THEN
    RAISE EXCEPTION 'Unknown invoice_id' USING ERRCODE = '45000';
  END IF;
  IF v_status IN ('PAID','CANCELLED') THEN
    RAISE EXCEPTION 'Invoice is already settled or cancelled' USING ERRCODE = '45000';
  END IF;

  v_late_now    := fn_late_fee(p_invoice_id, CURRENT_DATE);
  v_late_delta  := GREATEST(v_late_now - v_late, 0);
  v_outstanding := v_amount - v_discount + v_late + v_late_delta - v_paid;
  IF p_amount > v_outstanding THEN
    RAISE EXCEPTION 'Payment exceeds the outstanding balance (including late fee)' USING ERRCODE = '45000';
  END IF;

  INSERT INTO fee_payment (invoice_id, amount, payment_mode, late_fee_charged)
  VALUES (p_invoice_id, p_amount, p_mode, v_late_delta)
  RETURNING payment_id INTO v_pay_id;

  v_new_paid := v_paid + p_amount;
  UPDATE fee_invoice
     SET late_fee    = v_late + v_late_delta,
         amount_paid = v_new_paid,
         status      = CASE WHEN v_amount - v_discount + v_late + v_late_delta - v_new_paid <= 0
                            THEN 'PAID' ELSE 'PARTIALLY_PAID' END
   WHERE invoice_id = p_invoice_id;

  INSERT INTO receipt_counter (receipt_year, last_no)
  VALUES (EXTRACT(YEAR FROM CURRENT_DATE)::SMALLINT, 1)
  ON CONFLICT (receipt_year) DO UPDATE SET last_no = receipt_counter.last_no + 1
  RETURNING last_no INTO v_no;
  v_receipt_no := 'RCP-' || EXTRACT(YEAR FROM CURRENT_DATE)::INTEGER || '-' || LPAD(v_no::TEXT, 6, '0');
  INSERT INTO fee_receipt (receipt_no, payment_id) VALUES (v_receipt_no, v_pay_id);
  RETURN v_receipt_no;
END;
$$;

-- Every change to a fee head's amount / late-fee rate / due date is logged with old and new values.
CREATE FUNCTION tf_fee_structure_audit() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF OLD.amount IS DISTINCT FROM NEW.amount
     OR OLD.late_fee_per_day IS DISTINCT FROM NEW.late_fee_per_day
     OR OLD.due_date IS DISTINCT FROM NEW.due_date THEN
    INSERT INTO fee_audit_log (fee_structure_id, old_amount, new_amount, old_late_fee_per_day,
                               new_late_fee_per_day, old_due_date, new_due_date, changed_by)
    VALUES (NEW.fee_structure_id, OLD.amount, NEW.amount, OLD.late_fee_per_day,
            NEW.late_fee_per_day, OLD.due_date, NEW.due_date,
            COALESCE(NULLIF(current_setting('app.user', true), ''), current_user));
  END IF;
  RETURN NEW;
END;
$$;
CREATE TRIGGER trg_fee_structure_audit AFTER UPDATE ON fee_structure
  FOR EACH ROW EXECUTE FUNCTION tf_fee_structure_audit();

-- Monthly payroll: basic + DA + HRA + allowances - PF - professional tax - loss-of-pay
-- (approved unpaid leave from G4, pro-rated on the calendar days of the month).
-- Re-runnable: GENERATED lines of that month are rebuilt, PAID lines are left alone.
-- Returns the number of payslips generated.
CREATE FUNCTION sp_calculate_monthly_payroll(p_month INTEGER, p_year INTEGER) RETURNS INTEGER
LANGUAGE plpgsql AS $$
DECLARE
  v_first DATE;
  v_last  DATE;
  v_days  INTEGER;
  v_count INTEGER := 0;
BEGIN
  IF p_month NOT BETWEEN 1 AND 12 OR p_year NOT BETWEEN 2000 AND 2100 THEN
    RAISE EXCEPTION 'Invalid payroll month or year' USING ERRCODE = '45000';
  END IF;
  v_first := make_date(p_year, p_month, 1);
  v_last  := (v_first + INTERVAL '1 month - 1 day')::DATE;
  v_days  := EXTRACT(DAY FROM v_last)::INTEGER;

  DELETE FROM payroll WHERE pay_month = p_month AND pay_year = p_year AND status = 'GENERATED';

  INSERT INTO payroll (employee_id, pay_month, pay_year, basic_pay, da_amount, hra_amount, other_allowance,
                       gross_pay, pf_deduction, professional_tax, unpaid_leave_days, lop_deduction,
                       total_deductions, net_pay)
  SELECT t.employee_id, p_month, p_year, t.basic_pay, t.da, t.hra, t.other_allowance,
         t.gross, t.pf, t.professional_tax, t.unpaid_days, t.lop,
         t.pf + t.professional_tax + t.lop,
         t.gross - (t.pf + t.professional_tax + t.lop)
    FROM (SELECT e.employee_id, ss.basic_pay,
                 ROUND(ss.basic_pay * ss.da_pct  / 100, 2) AS da,
                 ROUND(ss.basic_pay * ss.hra_pct / 100, 2) AS hra,
                 ss.other_allowance,
                 ROUND(ss.basic_pay * (1 + ss.da_pct / 100 + ss.hra_pct / 100) + ss.other_allowance, 2) AS gross,
                 ROUND(ss.basic_pay * ss.pf_pct / 100, 2) AS pf,
                 ss.professional_tax,
                 COALESCE(ul.unpaid_days, 0) AS unpaid_days,
                 ROUND((ss.basic_pay * (1 + ss.da_pct / 100 + ss.hra_pct / 100) + ss.other_allowance)
                       / v_days * COALESCE(ul.unpaid_days, 0), 2) AS lop
            FROM employee e
            JOIN salary_structure ss
              ON ss.employee_id = e.employee_id
             AND ss.effective_from = (SELECT MAX(x.effective_from) FROM salary_structure x
                                       WHERE x.employee_id = e.employee_id AND x.effective_from <= v_last)
            LEFT JOIN (SELECT la.employee_id,
                              SUM((LEAST(la.to_date, v_last) - GREATEST(la.from_date, v_first)) + 1) AS unpaid_days
                         FROM leave_application la
                         JOIN leave_type lt ON lt.leave_type_id = la.leave_type_id AND lt.is_paid = 0
                        WHERE la.status = 'APPROVED' AND la.from_date <= v_last AND la.to_date >= v_first
                        GROUP BY la.employee_id) ul ON ul.employee_id = e.employee_id
           WHERE e.status IN ('ACTIVE','ON_LEAVE') AND e.joining_date <= v_last) t
   WHERE NOT EXISTS (SELECT 1 FROM payroll p
                      WHERE p.employee_id = t.employee_id AND p.pay_month = p_month AND p.pay_year = p_year);
  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count;
END;
$$;

-- Students with an overdue, unsettled invoice, incl. the late fee that has accrued but is not yet charged.
CREATE VIEW vw_fee_defaulters AS
SELECT s.student_id,
       s.full_name,
       p.dept_code,
       fs.fee_type,
       i.invoice_id,
       i.due_date,
       (CURRENT_DATE - i.due_date)                               AS days_overdue,
       i.balance                                                 AS balance_charged,
       GREATEST(fn_late_fee(i.invoice_id, CURRENT_DATE) - i.late_fee, 0) AS late_fee_accrued,
       i.balance + GREATEST(fn_late_fee(i.invoice_id, CURRENT_DATE) - i.late_fee, 0) AS total_payable
  FROM fee_invoice i
  JOIN fee_structure fs ON fs.fee_structure_id = i.fee_structure_id
  JOIN student s        ON s.student_id = i.student_id
  JOIN program p        ON p.program_id = s.program_id
 WHERE i.status IN ('UNPAID','PARTIALLY_PAID') AND i.due_date < CURRENT_DATE;

-- Accountant report: money collected per month with a running total.
CREATE VIEW vw_monthly_fee_collection AS
SELECT m.pay_month,
       m.payments,
       m.collected,
       SUM(m.collected) OVER (ORDER BY m.pay_month) AS running_total
  FROM (SELECT to_char(fp.paid_on, 'YYYY-MM') AS pay_month,
               COUNT(*)                       AS payments,
               SUM(fp.amount)                 AS collected
          FROM fee_payment fp
         WHERE fp.status = 'SUCCESS'
         GROUP BY to_char(fp.paid_on, 'YYYY-MM')) m;
