-- =====================================================================
-- 04_finance.sql   |  G5 - Fees & Finance Management
-- fee_structure, fee_invoice, fee_payment, fee_receipt (+ receipt_counter),
-- fee_audit_log, scholarship, salary_structure, payroll.
-- Depends on: 00_admin, 01_academics (employee), 02_students (student, room_allocation),
--             03_attendance (leave_application / leave_type for unpaid leave)
-- Provides:   fn_student_fee_due -> G2 (exam fee), G7 (placement no-dues), G1 dashboard
-- =====================================================================
SET NAMES utf8mb4;

CREATE TABLE fee_structure (
  fee_structure_id INT UNSIGNED     NOT NULL AUTO_INCREMENT,
  program_id       INT UNSIGNED     NOT NULL,
  academic_year_id INT UNSIGNED     NOT NULL,
  year_of_study    TINYINT UNSIGNED NOT NULL,
  fee_type         ENUM('TUITION','EXAM','LIBRARY','DEVELOPMENT','LAB','HOSTEL','OTHER') NOT NULL,
  amount           DECIMAL(10,2)    NOT NULL,
  late_fee_per_day DECIMAL(6,2)     NOT NULL DEFAULT 0.00,
  due_date         DATE             NOT NULL,
  created_at       TIMESTAMP        NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at       TIMESTAMP        NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT pk_fee_structure PRIMARY KEY (fee_structure_id),
  CONSTRAINT uq_fee_structure UNIQUE (program_id, academic_year_id, year_of_study, fee_type),
  CONSTRAINT fk_feestruct_program FOREIGN KEY (program_id)       REFERENCES program (program_id),
  CONSTRAINT fk_feestruct_ay      FOREIGN KEY (academic_year_id) REFERENCES academic_year (academic_year_id),
  CONSTRAINT ck_feestruct_amount  CHECK (amount > 0),
  CONSTRAINT ck_feestruct_late    CHECK (late_fee_per_day >= 0),
  CONSTRAINT ck_feestruct_year    CHECK (year_of_study BETWEEN 1 AND 6)
) ENGINE=InnoDB COMMENT='G5: fee heads per program, year of study and academic year';

CREATE TABLE fee_audit_log (
  audit_id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  fee_structure_id     INT UNSIGNED    NOT NULL,
  old_amount           DECIMAL(10,2)   NOT NULL,
  new_amount           DECIMAL(10,2)   NOT NULL,
  old_late_fee_per_day DECIMAL(6,2)    NOT NULL,
  new_late_fee_per_day DECIMAL(6,2)    NOT NULL,
  old_due_date         DATE            NOT NULL,
  new_due_date         DATE            NOT NULL,
  changed_by           VARCHAR(100)    NOT NULL,
  created_at           TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at           TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT pk_fee_audit_log PRIMARY KEY (audit_id),
  CONSTRAINT fk_feeaudit_structure FOREIGN KEY (fee_structure_id) REFERENCES fee_structure (fee_structure_id),
  KEY ix_feeaudit_structure (fee_structure_id, created_at)
) ENGINE=InnoDB COMMENT='G5: old/new values written by trg_fee_structure_audit';

CREATE TABLE fee_invoice (
  invoice_id       INT UNSIGNED  NOT NULL AUTO_INCREMENT,
  student_id       CHAR(11)      NOT NULL,
  fee_structure_id INT UNSIGNED  NOT NULL,
  amount           DECIMAL(10,2) NOT NULL COMMENT 'snapshot of the structure amount',
  discount         DECIMAL(10,2) NOT NULL DEFAULT 0.00,
  late_fee         DECIMAL(10,2) NOT NULL DEFAULT 0.00 COMMENT 'late fee charged so far',
  amount_paid      DECIMAL(10,2) NOT NULL DEFAULT 0.00,
  balance          DECIMAL(10,2) GENERATED ALWAYS AS (amount - discount + late_fee - amount_paid) STORED,
  due_date         DATE          NOT NULL,
  issued_on        DATE          NOT NULL DEFAULT (CURRENT_DATE),
  status           ENUM('UNPAID','PARTIALLY_PAID','PAID','CANCELLED') NOT NULL DEFAULT 'UNPAID',
  created_at       TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at       TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT pk_fee_invoice PRIMARY KEY (invoice_id),
  CONSTRAINT uq_fee_invoice UNIQUE (student_id, fee_structure_id),
  CONSTRAINT fk_invoice_student   FOREIGN KEY (student_id)       REFERENCES student (student_id),
  CONSTRAINT fk_invoice_structure FOREIGN KEY (fee_structure_id) REFERENCES fee_structure (fee_structure_id),
  CONSTRAINT ck_invoice_amount    CHECK (amount > 0),
  CONSTRAINT ck_invoice_discount  CHECK (discount >= 0 AND discount <= amount),
  CONSTRAINT ck_invoice_paid      CHECK (late_fee >= 0 AND amount_paid >= 0 AND amount_paid <= amount - discount + late_fee),
  KEY ix_invoice_status (status, due_date)
) ENGINE=InnoDB COMMENT='G5: one bill per student per fee head';

CREATE TABLE fee_payment (
  payment_id       INT UNSIGNED  NOT NULL AUTO_INCREMENT,
  invoice_id       INT UNSIGNED  NOT NULL,
  amount           DECIMAL(10,2) NOT NULL,
  payment_mode     ENUM('CASH','UPI','CARD','NET_BANKING','CHEQUE','DD') NOT NULL,
  transaction_ref  VARCHAR(40)   NULL,
  paid_on          DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
  late_fee_charged DECIMAL(10,2) NOT NULL DEFAULT 0.00 COMMENT 'late fee added to the invoice by this payment',
  status           ENUM('SUCCESS','FAILED','REVERSED') NOT NULL DEFAULT 'SUCCESS',
  created_at       TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at       TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT pk_fee_payment PRIMARY KEY (payment_id),
  CONSTRAINT fk_payment_invoice FOREIGN KEY (invoice_id) REFERENCES fee_invoice (invoice_id),
  CONSTRAINT ck_payment_amount  CHECK (amount > 0),
  CONSTRAINT ck_payment_late    CHECK (late_fee_charged >= 0),
  KEY ix_payment_paid_on (paid_on)
) ENGINE=InnoDB COMMENT='G5: money received';

CREATE TABLE receipt_counter (
  receipt_year SMALLINT UNSIGNED NOT NULL,
  last_no      INT UNSIGNED      NOT NULL DEFAULT 0,
  created_at   TIMESTAMP         NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at   TIMESTAMP         NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT pk_receipt_counter PRIMARY KEY (receipt_year)
) ENGINE=InnoDB COMMENT='G5: gap-free receipt serial per calendar year';

CREATE TABLE fee_receipt (
  receipt_no VARCHAR(16)  NOT NULL COMMENT 'RCP-2026-000123',
  payment_id INT UNSIGNED NOT NULL,
  issued_on  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  created_at TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT pk_fee_receipt PRIMARY KEY (receipt_no),
  CONSTRAINT uq_fee_receipt_payment UNIQUE (payment_id),
  CONSTRAINT fk_receipt_payment FOREIGN KEY (payment_id) REFERENCES fee_payment (payment_id),
  CONSTRAINT ck_receipt_no CHECK (receipt_no REGEXP '^RCP-[0-9]{4}-[0-9]{6}$')
) ENGINE=InnoDB COMMENT='G5: one receipt per payment';

CREATE TABLE scholarship (
  scholarship_id   INT UNSIGNED  NOT NULL AUTO_INCREMENT,
  student_id       CHAR(11)      NOT NULL,
  academic_year_id INT UNSIGNED  NOT NULL,
  scholarship_name VARCHAR(100)  NOT NULL,
  provider         VARCHAR(100)  NULL,
  amount           DECIMAL(10,2) NOT NULL,
  status           ENUM('APPLIED','APPROVED','REJECTED','DISBURSED') NOT NULL DEFAULT 'APPLIED',
  decided_on       DATE          NULL,
  created_at       TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at       TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT pk_scholarship PRIMARY KEY (scholarship_id),
  CONSTRAINT uq_scholarship UNIQUE (student_id, academic_year_id, scholarship_name),
  CONSTRAINT fk_scholarship_student FOREIGN KEY (student_id)       REFERENCES student (student_id),
  CONSTRAINT fk_scholarship_ay      FOREIGN KEY (academic_year_id) REFERENCES academic_year (academic_year_id),
  CONSTRAINT ck_scholarship_amount  CHECK (amount > 0)
) ENGINE=InnoDB COMMENT='G5: scholarships awarded to students';

CREATE TABLE salary_structure (
  salary_structure_id INT UNSIGNED  NOT NULL AUTO_INCREMENT,
  employee_id         CHAR(7)       NOT NULL,
  effective_from      DATE          NOT NULL,
  basic_pay           DECIMAL(10,2) NOT NULL,
  da_pct              DECIMAL(5,2)  NOT NULL DEFAULT 0.00,
  hra_pct             DECIMAL(5,2)  NOT NULL DEFAULT 0.00,
  other_allowance     DECIMAL(10,2) NOT NULL DEFAULT 0.00,
  pf_pct              DECIMAL(5,2)  NOT NULL DEFAULT 0.00,
  professional_tax    DECIMAL(10,2) NOT NULL DEFAULT 0.00,
  created_at          TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at          TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT pk_salary_structure PRIMARY KEY (salary_structure_id),
  CONSTRAINT uq_salary_structure UNIQUE (employee_id, effective_from),
  CONSTRAINT fk_salary_employee FOREIGN KEY (employee_id) REFERENCES employee (employee_id),
  CONSTRAINT ck_salary_basic CHECK (basic_pay > 0),
  CONSTRAINT ck_salary_pcts  CHECK (da_pct BETWEEN 0 AND 200 AND hra_pct BETWEEN 0 AND 100 AND pf_pct BETWEEN 0 AND 100),
  CONSTRAINT ck_salary_other CHECK (other_allowance >= 0 AND professional_tax >= 0)
) ENGINE=InnoDB COMMENT='G5: pay components; the row with the latest effective_from applies';

CREATE TABLE payroll (
  payroll_id        INT UNSIGNED  NOT NULL AUTO_INCREMENT,
  employee_id       CHAR(7)       NOT NULL,
  pay_month         TINYINT UNSIGNED NOT NULL,
  pay_year          SMALLINT UNSIGNED NOT NULL,
  basic_pay         DECIMAL(10,2) NOT NULL,
  da_amount         DECIMAL(10,2) NOT NULL,
  hra_amount        DECIMAL(10,2) NOT NULL,
  other_allowance   DECIMAL(10,2) NOT NULL,
  gross_pay         DECIMAL(10,2) NOT NULL,
  pf_deduction      DECIMAL(10,2) NOT NULL,
  professional_tax  DECIMAL(10,2) NOT NULL,
  unpaid_leave_days DECIMAL(4,1)  NOT NULL DEFAULT 0,
  lop_deduction     DECIMAL(10,2) NOT NULL DEFAULT 0.00,
  total_deductions  DECIMAL(10,2) NOT NULL,
  net_pay           DECIMAL(10,2) NOT NULL,
  status            ENUM('GENERATED','PAID') NOT NULL DEFAULT 'GENERATED',
  generated_on      DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
  created_at        TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at        TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT pk_payroll PRIMARY KEY (payroll_id),
  CONSTRAINT uq_payroll UNIQUE (employee_id, pay_month, pay_year),
  CONSTRAINT fk_payroll_employee FOREIGN KEY (employee_id) REFERENCES employee (employee_id),
  CONSTRAINT ck_payroll_month CHECK (pay_month BETWEEN 1 AND 12),
  CONSTRAINT ck_payroll_year  CHECK (pay_year BETWEEN 2000 AND 2100),
  CONSTRAINT ck_payroll_net   CHECK (net_pay >= 0)
) ENGINE=InnoDB COMMENT='G5: monthly payslip lines';

-- ---------------------------------------------------------------------
-- SQL OBJECTS
-- ---------------------------------------------------------------------
DELIMITER $$

-- Late fee on an invoice if it were paid on p_pay_date: whole days after the due date x the head's per-day rate.
CREATE FUNCTION fn_late_fee(p_invoice_id INT UNSIGNED, p_pay_date DATE) RETURNS DECIMAL(10,2)
  READS SQL DATA
BEGIN
  DECLARE v_due  DATE;
  DECLARE v_rate DECIMAL(6,2);
  SELECT i.due_date, fs.late_fee_per_day INTO v_due, v_rate
    FROM fee_invoice i JOIN fee_structure fs ON fs.fee_structure_id = i.fee_structure_id
   WHERE i.invoice_id = p_invoice_id;
  IF v_due IS NULL THEN
    RETURN NULL;
  END IF;
  RETURN GREATEST(DATEDIFF(p_pay_date, v_due), 0) * v_rate;
END$$

-- Outstanding amount of a student (optionally one fee type, optionally only overdue invoices).
CREATE FUNCTION fn_student_fee_due(p_student_id CHAR(11), p_fee_type VARCHAR(12), p_overdue_only TINYINT)
  RETURNS DECIMAL(10,2)
  READS SQL DATA
BEGIN
  DECLARE v_due DECIMAL(10,2);
  SELECT IFNULL(SUM(i.balance), 0) INTO v_due
    FROM fee_invoice i JOIN fee_structure fs ON fs.fee_structure_id = i.fee_structure_id
   WHERE i.student_id = p_student_id
     AND i.status IN ('UNPAID','PARTIALLY_PAID')
     AND (p_fee_type IS NULL OR fs.fee_type = p_fee_type)
     AND (IFNULL(p_overdue_only, 0) = 0 OR i.due_date < CURDATE());
  RETURN v_due;
END$$

-- Creates invoices for every active student of a program who is in a given year of study during an
-- academic year (derived from semester_registration). HOSTEL fees only for students holding a bed.
CREATE PROCEDURE sp_generate_fee_invoices(
  IN p_program_id INT UNSIGNED, IN p_academic_year_id INT UNSIGNED, IN p_year_of_study TINYINT UNSIGNED)
BEGIN
  DECLARE v_created INT DEFAULT 0;
  DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; RESIGNAL; END;
  START TRANSACTION;
  INSERT INTO fee_invoice (student_id, fee_structure_id, amount, due_date)
  SELECT DISTINCT sr.student_id, fs.fee_structure_id, fs.amount, fs.due_date
    FROM fee_structure fs
    JOIN semester sm ON sm.academic_year_id = fs.academic_year_id
    JOIN semester_registration sr ON sr.semester_id = sm.semester_id AND sr.status = 'REGISTERED'
                                 AND CEIL(sr.sem_no / 2) = fs.year_of_study
    JOIN student s ON s.student_id = sr.student_id AND s.program_id = fs.program_id AND s.status = 'ACTIVE'
   WHERE fs.program_id = p_program_id AND fs.academic_year_id = p_academic_year_id
     AND fs.year_of_study = p_year_of_study
     AND (fs.fee_type <> 'HOSTEL'
          OR EXISTS (SELECT 1 FROM room_allocation ra WHERE ra.student_id = s.student_id AND ra.status = 'ACTIVE'))
     AND NOT EXISTS (SELECT 1 FROM fee_invoice fi
                      WHERE fi.student_id = sr.student_id AND fi.fee_structure_id = fs.fee_structure_id);
  SET v_created = ROW_COUNT();
  COMMIT;
  SELECT v_created AS invoices_created;
END$$

-- Pays (part of) an invoice in ONE transaction: late fee is brought up to date, the payment is
-- stored, the invoice balance/status updated and a receipt number (RCP-YYYY-NNNNNN) issued.
CREATE PROCEDURE sp_process_fee_payment(
  IN  p_invoice_id INT UNSIGNED,
  IN  p_amount     DECIMAL(10,2),
  IN  p_mode       VARCHAR(12),
  OUT p_receipt_no VARCHAR(16))
BEGIN
  DECLARE v_amount DECIMAL(10,2); DECLARE v_discount DECIMAL(10,2);
  DECLARE v_late DECIMAL(10,2);   DECLARE v_paid DECIMAL(10,2);
  DECLARE v_status VARCHAR(15);   DECLARE v_late_now DECIMAL(10,2);
  DECLARE v_late_delta DECIMAL(10,2); DECLARE v_outstanding DECIMAL(10,2);
  DECLARE v_new_paid DECIMAL(10,2);   DECLARE v_pay_id INT UNSIGNED; DECLARE v_no INT UNSIGNED;
  DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; RESIGNAL; END;

  IF p_amount IS NULL OR p_amount <= 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Payment amount must be positive';
  END IF;

  START TRANSACTION;
    SELECT amount, discount, late_fee, amount_paid, status
      INTO v_amount, v_discount, v_late, v_paid, v_status
      FROM fee_invoice WHERE invoice_id = p_invoice_id FOR UPDATE;
    IF v_status IS NULL THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Unknown invoice_id';
    END IF;
    IF v_status IN ('PAID','CANCELLED') THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Invoice is already settled or cancelled';
    END IF;

    SET v_late_now   = fn_late_fee(p_invoice_id, CURDATE());
    SET v_late_delta = GREATEST(v_late_now - v_late, 0);
    SET v_outstanding = v_amount - v_discount + v_late + v_late_delta - v_paid;
    IF p_amount > v_outstanding THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Payment exceeds the outstanding balance (including late fee)';
    END IF;

    INSERT INTO fee_payment (invoice_id, amount, payment_mode, late_fee_charged)
    VALUES (p_invoice_id, p_amount, p_mode, v_late_delta);
    SET v_pay_id = LAST_INSERT_ID();

    SET v_new_paid = v_paid + p_amount;
    UPDATE fee_invoice
       SET late_fee    = v_late + v_late_delta,
           amount_paid = v_new_paid,
           status      = IF(v_amount - v_discount + v_late + v_late_delta - v_new_paid <= 0, 'PAID', 'PARTIALLY_PAID')
     WHERE invoice_id = p_invoice_id;

    INSERT INTO receipt_counter (receipt_year, last_no) VALUES (YEAR(CURDATE()), LAST_INSERT_ID(1))
      ON DUPLICATE KEY UPDATE last_no = LAST_INSERT_ID(last_no + 1);
    SET v_no = LAST_INSERT_ID();
    SET p_receipt_no = CONCAT('RCP-', YEAR(CURDATE()), '-', LPAD(v_no, 6, '0'));
    INSERT INTO fee_receipt (receipt_no, payment_id) VALUES (p_receipt_no, v_pay_id);
  COMMIT;
END$$

-- Every change to a fee head's amount / late-fee rate / due date is logged with old and new values.
CREATE TRIGGER trg_fee_structure_audit AFTER UPDATE ON fee_structure
FOR EACH ROW
BEGIN
  IF NOT (OLD.amount <=> NEW.amount AND OLD.late_fee_per_day <=> NEW.late_fee_per_day
          AND OLD.due_date <=> NEW.due_date) THEN
    INSERT INTO fee_audit_log (fee_structure_id, old_amount, new_amount, old_late_fee_per_day,
                               new_late_fee_per_day, old_due_date, new_due_date, changed_by)
    VALUES (NEW.fee_structure_id, OLD.amount, NEW.amount, OLD.late_fee_per_day,
            NEW.late_fee_per_day, OLD.due_date, NEW.due_date, COALESCE(@app_user, CURRENT_USER()));
  END IF;
END$$

-- Monthly payroll: basic + DA + HRA + allowances - PF - professional tax - loss-of-pay
-- (approved unpaid leave from G4, pro-rated on the calendar days of the month).
-- Re-runnable: GENERATED lines of that month are rebuilt, PAID lines are left alone.
CREATE PROCEDURE sp_calculate_monthly_payroll(IN p_month TINYINT UNSIGNED, IN p_year SMALLINT UNSIGNED)
BEGIN
  DECLARE v_first DATE; DECLARE v_last DATE; DECLARE v_days INT; DECLARE v_count INT DEFAULT 0;
  DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; RESIGNAL; END;

  IF p_month NOT BETWEEN 1 AND 12 OR p_year NOT BETWEEN 2000 AND 2100 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Invalid payroll month or year';
  END IF;
  SET v_first = MAKEDATE(p_year, 1) + INTERVAL (p_month - 1) MONTH;
  SET v_last  = LAST_DAY(v_first);
  SET v_days  = DAY(v_last);

  START TRANSACTION;
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
                   IFNULL(ul.unpaid_days, 0) AS unpaid_days,
                   ROUND((ss.basic_pay * (1 + ss.da_pct / 100 + ss.hra_pct / 100) + ss.other_allowance)
                         / v_days * IFNULL(ul.unpaid_days, 0), 2) AS lop
              FROM employee e
              JOIN salary_structure ss
                ON ss.employee_id = e.employee_id
               AND ss.effective_from = (SELECT MAX(x.effective_from) FROM salary_structure x
                                         WHERE x.employee_id = e.employee_id AND x.effective_from <= v_last)
              LEFT JOIN (SELECT la.employee_id,
                                SUM(DATEDIFF(LEAST(la.to_date, v_last), GREATEST(la.from_date, v_first)) + 1) AS unpaid_days
                           FROM leave_application la
                           JOIN leave_type lt ON lt.leave_type_id = la.leave_type_id AND lt.is_paid = 0
                          WHERE la.status = 'APPROVED' AND la.from_date <= v_last AND la.to_date >= v_first
                          GROUP BY la.employee_id) ul ON ul.employee_id = e.employee_id
             WHERE e.status IN ('ACTIVE','ON_LEAVE') AND e.joining_date <= v_last) t
     WHERE NOT EXISTS (SELECT 1 FROM payroll p
                        WHERE p.employee_id = t.employee_id AND p.pay_month = p_month AND p.pay_year = p_year);
    SET v_count = ROW_COUNT();
  COMMIT;
  SELECT v_count AS payslips_generated, p_month AS pay_month, p_year AS pay_year;
END$$

DELIMITER ;

-- Students with an overdue, unsettled invoice, incl. the late fee that has accrued but is not yet charged.
CREATE VIEW vw_fee_defaulters AS
SELECT s.student_id,
       s.full_name,
       p.dept_code,
       fs.fee_type,
       i.invoice_id,
       i.due_date,
       DATEDIFF(CURDATE(), i.due_date)                           AS days_overdue,
       i.balance                                                 AS balance_charged,
       GREATEST(fn_late_fee(i.invoice_id, CURDATE()) - i.late_fee, 0) AS late_fee_accrued,
       i.balance + GREATEST(fn_late_fee(i.invoice_id, CURDATE()) - i.late_fee, 0) AS total_payable
  FROM fee_invoice i
  JOIN fee_structure fs ON fs.fee_structure_id = i.fee_structure_id
  JOIN student s        ON s.student_id = i.student_id
  JOIN program p        ON p.program_id = s.program_id
 WHERE i.status IN ('UNPAID','PARTIALLY_PAID') AND i.due_date < CURDATE();

-- Accountant report: money collected per month with a running total.
CREATE VIEW vw_monthly_fee_collection AS
SELECT m.pay_month,
       m.payments,
       m.collected,
       SUM(m.collected) OVER (ORDER BY m.pay_month) AS running_total
  FROM (SELECT DATE_FORMAT(fp.paid_on, '%Y-%m') AS pay_month,
               COUNT(*)                         AS payments,
               SUM(fp.amount)                   AS collected
          FROM fee_payment fp
         WHERE fp.status = 'SUCCESS'
         GROUP BY DATE_FORMAT(fp.paid_on, '%Y-%m')) m;
