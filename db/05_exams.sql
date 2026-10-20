-- =====================================================================
-- 05_exams.sql   |  G2 - Examination & Results Management
-- grade_scale, exam, exam_schedule, exam_registration, hall_ticket, marks, result.
-- Depends on: 00_admin, 01_academics (course, course_offering, classroom, employee),
--             02_students (student), 03_attendance (fn_attendance_percentage),
--             04_finance (fn_student_fee_due)
-- Provides:   fn_calculate_cgpa -> G7 (placement eligibility) and G1 dashboard
-- =====================================================================
SET NAMES utf8mb4;

CREATE TABLE grade_scale (
  grade       VARCHAR(2)    NOT NULL,
  min_pct     DECIMAL(5,2)  NOT NULL COMMENT 'lowest percentage that earns this grade',
  grade_point DECIMAL(3,1)  NOT NULL,
  is_pass     TINYINT(1)    NOT NULL,
  description VARCHAR(40)   NULL,
  created_at  TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at  TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT pk_grade_scale PRIMARY KEY (grade),
  CONSTRAINT uq_grade_scale_min UNIQUE (min_pct),
  CONSTRAINT ck_grade_scale_pct   CHECK (min_pct BETWEEN 0 AND 100),
  CONSTRAINT ck_grade_scale_point CHECK (grade_point BETWEEN 0 AND 10)
) ENGINE=InnoDB COMMENT='G2: percentage -> grade -> grade point (10 point scale)';

CREATE TABLE exam (
  exam_id               VARCHAR(12) NOT NULL COMMENT 'EX-2026-S5-01',
  exam_name             VARCHAR(100) NOT NULL,
  exam_type             ENUM('ISE','MSE','ESE','PRACTICAL','ORAL') NOT NULL DEFAULT 'ESE',
  semester_id           INT UNSIGNED NOT NULL,
  sem_no                TINYINT UNSIGNED NOT NULL,
  registration_deadline DATE         NULL,
  start_date            DATE         NOT NULL,
  end_date              DATE         NOT NULL,
  status                ENUM('SCHEDULED','REGISTRATION_OPEN','ONGOING','COMPLETED','RESULTS_PUBLISHED')
                          NOT NULL DEFAULT 'SCHEDULED',
  created_at            TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at            TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT pk_exam PRIMARY KEY (exam_id),
  CONSTRAINT fk_exam_semester FOREIGN KEY (semester_id) REFERENCES semester (semester_id),
  CONSTRAINT ck_exam_id    CHECK (exam_id REGEXP '^EX-[0-9]{4}-S[0-9]-[0-9]{2}$'),
  CONSTRAINT ck_exam_sem   CHECK (sem_no BETWEEN 1 AND 8),
  CONSTRAINT ck_exam_dates CHECK (end_date >= start_date)
) ENGINE=InnoDB COMMENT='G2: an examination event of a semester';

CREATE TABLE exam_schedule (
  schedule_id   INT UNSIGNED  NOT NULL AUTO_INCREMENT,
  exam_id       VARCHAR(12)   NOT NULL,
  offering_id   INT UNSIGNED  NOT NULL,
  exam_date     DATE          NOT NULL,
  start_time    TIME          NOT NULL,
  end_time      TIME          NOT NULL,
  max_marks     SMALLINT UNSIGNED NOT NULL,
  passing_marks SMALLINT UNSIGNED NOT NULL,
  created_at    TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at    TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT pk_exam_schedule PRIMARY KEY (schedule_id),
  CONSTRAINT uq_exam_schedule UNIQUE (exam_id, offering_id),
  CONSTRAINT fk_examsch_exam     FOREIGN KEY (exam_id)     REFERENCES exam (exam_id),
  CONSTRAINT fk_examsch_offering FOREIGN KEY (offering_id) REFERENCES course_offering (offering_id),
  CONSTRAINT ck_examsch_marks CHECK (max_marks > 0 AND passing_marks <= max_marks),
  CONSTRAINT ck_examsch_times CHECK (end_time > start_time)
) ENGINE=InnoDB COMMENT='G2: which course is examined when, and out of how many marks';

CREATE TABLE exam_registration (
  registration_id INT UNSIGNED NOT NULL AUTO_INCREMENT,
  exam_id         VARCHAR(12)  NOT NULL,
  student_id      CHAR(11)     NOT NULL,
  offering_id     INT UNSIGNED NOT NULL,
  status          ENUM('REGISTERED','CANCELLED') NOT NULL DEFAULT 'REGISTERED',
  registered_on   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  created_at      TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at      TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT pk_exam_registration PRIMARY KEY (registration_id),
  CONSTRAINT uq_exam_registration UNIQUE (student_id, exam_id, offering_id),
  CONSTRAINT fk_examreg_student  FOREIGN KEY (student_id) REFERENCES student (student_id),
  CONSTRAINT fk_examreg_schedule FOREIGN KEY (exam_id, offering_id) REFERENCES exam_schedule (exam_id, offering_id),
  KEY ix_examreg_exam (exam_id, status)
) ENGINE=InnoDB COMMENT='G2: student registers for a scheduled course exam (blocked below 75% attendance)';

CREATE TABLE hall_ticket (
  hall_ticket_id INT UNSIGNED NOT NULL AUTO_INCREMENT,
  hall_ticket_no VARCHAR(20)  NOT NULL COMMENT 'HT-EX-2026-S5-01-0001',
  exam_id        VARCHAR(12)  NOT NULL,
  student_id     CHAR(11)     NOT NULL,
  seat_no        VARCHAR(10)  NOT NULL,
  issued_on      DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  created_at     TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at     TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT pk_hall_ticket PRIMARY KEY (hall_ticket_id),
  CONSTRAINT uq_hall_ticket_no      UNIQUE (hall_ticket_no),
  CONSTRAINT uq_hall_ticket_student UNIQUE (exam_id, student_id),
  CONSTRAINT uq_hall_ticket_seat    UNIQUE (exam_id, seat_no),
  CONSTRAINT fk_hallticket_exam    FOREIGN KEY (exam_id)    REFERENCES exam (exam_id),
  CONSTRAINT fk_hallticket_student FOREIGN KEY (student_id) REFERENCES student (student_id)
) ENGINE=InnoDB COMMENT='G2: issued only to registered, eligible students';

CREATE TABLE marks (
  marks_id       INT UNSIGNED  NOT NULL AUTO_INCREMENT,
  exam_id        VARCHAR(12)   NOT NULL,
  student_id     CHAR(11)      NOT NULL,
  offering_id    INT UNSIGNED  NOT NULL,
  marks_obtained DECIMAL(5,2)  NULL,
  is_absent      TINYINT(1)    NOT NULL DEFAULT 0,
  entered_by     CHAR(7)       NULL,
  created_at     TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at     TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT pk_marks PRIMARY KEY (marks_id),
  CONSTRAINT uq_marks UNIQUE (student_id, exam_id, offering_id),
  CONSTRAINT fk_marks_registration FOREIGN KEY (student_id, exam_id, offering_id)
                                   REFERENCES exam_registration (student_id, exam_id, offering_id),
  CONSTRAINT fk_marks_employee FOREIGN KEY (entered_by) REFERENCES employee (employee_id),
  CONSTRAINT ck_marks_value CHECK ((is_absent = 1 AND marks_obtained IS NULL)
                                OR (is_absent = 0 AND marks_obtained IS NOT NULL AND marks_obtained >= 0))
) ENGINE=InnoDB COMMENT='G2: marks per registered exam; upper bound enforced by trg_marks_max_check';

CREATE TABLE result (
  result_id    INT UNSIGNED  NOT NULL AUTO_INCREMENT,
  student_id   CHAR(11)      NOT NULL,
  offering_id  INT UNSIGNED  NOT NULL,
  total_marks  DECIMAL(6,2)  NOT NULL,
  max_marks    DECIMAL(6,2)  NOT NULL,
  percentage   DECIMAL(5,2)  GENERATED ALWAYS AS (ROUND(total_marks * 100 / max_marks, 2)) STORED,
  grade        VARCHAR(2)    NOT NULL,
  published_on DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
  created_at   TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at   TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT pk_result PRIMARY KEY (result_id),
  CONSTRAINT uq_result UNIQUE (student_id, offering_id),
  CONSTRAINT fk_result_student  FOREIGN KEY (student_id)  REFERENCES student (student_id),
  CONSTRAINT fk_result_offering FOREIGN KEY (offering_id) REFERENCES course_offering (offering_id),
  CONSTRAINT fk_result_grade    FOREIGN KEY (grade)       REFERENCES grade_scale (grade),
  CONSTRAINT ck_result_marks CHECK (max_marks > 0 AND total_marks >= 0 AND total_marks <= max_marks),
  KEY ix_result_offering (offering_id)
) ENGINE=InnoDB COMMENT='G2: published course result; credits and grade points come from course / grade_scale';

CREATE TABLE marks_submission (
  submission_id INT UNSIGNED NOT NULL AUTO_INCREMENT,
  exam_id VARCHAR(16) NOT NULL,
  offering_id INT UNSIGNED NOT NULL,
  status ENUM('DRAFT', 'SUBMITTED', 'UNDER_REVIEW', 'APPROVED', 'REJECTED') NOT NULL DEFAULT 'DRAFT',
  submitted_by CHAR(7) NULL,
  submitted_at TIMESTAMP NULL,
  reviewed_by INT UNSIGNED NULL,
  reviewed_at TIMESTAMP NULL,
  rejection_reason TEXT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT pk_marks_submission PRIMARY KEY (submission_id),
  CONSTRAINT uq_marks_submission UNIQUE (exam_id, offering_id),
  CONSTRAINT fk_marksub_exam FOREIGN KEY (exam_id) REFERENCES exam (exam_id) ON DELETE CASCADE,
  CONSTRAINT fk_marksub_offering FOREIGN KEY (offering_id) REFERENCES course_offering (offering_id) ON DELETE CASCADE,
  KEY ix_marksub_exam (exam_id, status)
) ENGINE=InnoDB COMMENT='G2: review and approval lifecycle for course examination marks';

CREATE TABLE backlog_exam_form (
  form_id         INT UNSIGNED NOT NULL AUTO_INCREMENT,
  form_no         VARCHAR(32)  NOT NULL,
  student_id      CHAR(11)     NOT NULL,
  exam_id         VARCHAR(12)  NOT NULL,
  academic_year   VARCHAR(20)  NOT NULL DEFAULT '2026-27',
  total_subjects  TINYINT UNSIGNED NOT NULL DEFAULT 1,
  total_credits   TINYINT UNSIGNED NOT NULL DEFAULT 3,
  base_fee        DECIMAL(8,2) NOT NULL DEFAULT 250.00,
  per_subject_fee DECIMAL(8,2) NOT NULL DEFAULT 350.00,
  total_fee       DECIMAL(8,2) NOT NULL,
  payment_mode    VARCHAR(30)  NOT NULL DEFAULT 'ONLINE',
  payment_status  ENUM('PENDING','PAID','EXEMPTED','FAILED') NOT NULL DEFAULT 'PAID',
  payment_reference VARCHAR(64) NULL,
  status          ENUM('SUBMITTED','UNDER_REVIEW','APPROVED','REJECTED','CANCELLED') NOT NULL DEFAULT 'SUBMITTED',
  remarks         TEXT         NULL,
  reviewed_by     CHAR(7)      NULL,
  reviewed_at     TIMESTAMP    NULL,
  created_at      TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at      TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT pk_backlog_exam_form PRIMARY KEY (form_id),
  CONSTRAINT uq_backlog_exam_form_no UNIQUE (form_no),
  CONSTRAINT fk_backlogform_student FOREIGN KEY (student_id) REFERENCES student (student_id),
  CONSTRAINT fk_backlogform_exam FOREIGN KEY (exam_id) REFERENCES exam (exam_id),
  CONSTRAINT fk_backlogform_reviewed_by FOREIGN KEY (reviewed_by) REFERENCES employee (employee_id)
) ENGINE=InnoDB COMMENT='G2: examination registration form submitted by failed students for backlogs';

CREATE TABLE backlog_exam_form_item (
  item_id         INT UNSIGNED NOT NULL AUTO_INCREMENT,
  form_id         INT UNSIGNED NOT NULL,
  offering_id     INT UNSIGNED NOT NULL,
  course_code     VARCHAR(20)  NOT NULL,
  course_title    VARCHAR(150) NOT NULL,
  semester_term   VARCHAR(40)  NULL,
  credits         TINYINT UNSIGNED NOT NULL DEFAULT 3,
  previous_grade  VARCHAR(2)   NOT NULL DEFAULT 'F',
  previous_marks  DECIMAL(5,2) NULL,
  attempt_no      TINYINT UNSIGNED NOT NULL DEFAULT 2,
  fee_amount      DECIMAL(8,2) NOT NULL DEFAULT 350.00,
  created_at      TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT pk_backlog_exam_form_item PRIMARY KEY (item_id),
  CONSTRAINT fk_backlogitem_form FOREIGN KEY (form_id) REFERENCES backlog_exam_form (form_id) ON DELETE CASCADE,
  CONSTRAINT fk_backlogitem_offering FOREIGN KEY (offering_id) REFERENCES course_offering (offering_id)
) ENGINE=InnoDB COMMENT='G2: course subjects selected for re-examination in a backlog form';

-- ---------------------------------------------------------------------
-- SQL OBJECTS
-- ---------------------------------------------------------------------
DELIMITER $$

-- Credit-weighted CGPA over all the student's courses (best attempt per course counts).
-- NULL when the student has no published result yet.
CREATE FUNCTION fn_calculate_cgpa(p_student_id CHAR(11)) RETURNS DECIMAL(4,2)
  READS SQL DATA
BEGIN
  DECLARE v_cgpa DECIMAL(4,2);
  SELECT ROUND(SUM(t.credits * t.gp) / SUM(t.credits), 2) INTO v_cgpa
    FROM (SELECT c.course_code, c.credits, MAX(g.grade_point) AS gp
            FROM result r
            JOIN course_offering o ON o.offering_id = r.offering_id
            JOIN course c          ON c.course_code = o.course_code
            JOIN grade_scale g     ON g.grade = r.grade
           WHERE r.student_id = p_student_id
           GROUP BY c.course_code, c.credits) t;
  RETURN v_cgpa;
END$$

-- SGPA: the same weighting restricted to one semester.
CREATE FUNCTION fn_calculate_sgpa(p_student_id CHAR(11), p_semester_id INT UNSIGNED) RETURNS DECIMAL(4,2)
  READS SQL DATA
BEGIN
  DECLARE v_sgpa DECIMAL(4,2);
  SELECT ROUND(SUM(c.credits * g.grade_point) / SUM(c.credits), 2) INTO v_sgpa
    FROM result r
    JOIN course_offering o ON o.offering_id = r.offering_id AND o.semester_id = p_semester_id
    JOIN course c          ON c.course_code = o.course_code
    JOIN grade_scale g     ON g.grade = r.grade
   WHERE r.student_id = p_student_id;
  RETURN v_sgpa;
END$$

-- Registration is refused when attendance in that course is below min_attendance_pct (75).
CREATE PROCEDURE sp_assert_exam_attendance(IN p_student_id CHAR(11), IN p_offering_id INT UNSIGNED)
BEGIN
  DECLARE v_pct DECIMAL(5,2);
  DECLARE v_min DECIMAL(12,2);
  DECLARE v_msg VARCHAR(128);
  SET v_pct = fn_attendance_percentage(p_student_id, p_offering_id);
  SET v_min = fn_setting_num('min_attendance_pct');
  IF v_pct < v_min THEN
    SET v_msg = CONCAT('Exam registration blocked: attendance ', v_pct, '% is below ', v_min, '%');
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
  END IF;
END$$

CREATE TRIGGER trg_exam_registration_attendance BEFORE INSERT ON exam_registration
FOR EACH ROW
BEGIN
  IF NEW.status = 'REGISTERED' THEN
    CALL sp_assert_exam_attendance(NEW.student_id, NEW.offering_id);
  END IF;
END$$

CREATE TRIGGER trg_exam_registration_attendance_upd BEFORE UPDATE ON exam_registration
FOR EACH ROW
BEGIN
  IF NEW.status = 'REGISTERED' AND OLD.status <> 'REGISTERED' THEN
    CALL sp_assert_exam_attendance(NEW.student_id, NEW.offering_id);
  END IF;
END$$

-- Marks cannot exceed the maximum of that scheduled paper.
CREATE TRIGGER trg_marks_max_check BEFORE INSERT ON marks
FOR EACH ROW
BEGIN
  DECLARE v_max SMALLINT UNSIGNED;
  SELECT max_marks INTO v_max FROM exam_schedule WHERE exam_id = NEW.exam_id AND offering_id = NEW.offering_id;
  IF NEW.marks_obtained > v_max THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Marks exceed the maximum marks of this paper';
  END IF;
END$$

CREATE TRIGGER trg_marks_max_check_upd BEFORE UPDATE ON marks
FOR EACH ROW
BEGIN
  DECLARE v_max SMALLINT UNSIGNED;
  SELECT max_marks INTO v_max FROM exam_schedule WHERE exam_id = NEW.exam_id AND offering_id = NEW.offering_id;
  IF NEW.marks_obtained > v_max THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Marks exceed the maximum marks of this paper';
  END IF;
END$$

-- Hall tickets for students who are registered AND still eligible:
--   attendance >= minimum in every registered course, and no unpaid EXAM-type fee.
CREATE PROCEDURE sp_generate_hall_tickets(IN p_exam_id VARCHAR(12))
BEGIN
  DECLARE v_issued INT DEFAULT 0;
  DECLARE v_skipped INT DEFAULT 0;
  DECLARE v_min DECIMAL(12,2);
  DECLARE v_offset INT DEFAULT 0;
  DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; RESIGNAL; END;

  IF NOT EXISTS (SELECT 1 FROM exam WHERE exam_id = p_exam_id) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Unknown exam_id';
  END IF;
  SET v_min = fn_setting_num('min_attendance_pct');

  -- eligible = registered students with no failing course attendance and no unpaid exam fee
  CREATE TEMPORARY TABLE IF NOT EXISTS tmp_eligible (student_id CHAR(11) NOT NULL PRIMARY KEY);
  DELETE FROM tmp_eligible;
  INSERT INTO tmp_eligible (student_id)
  SELECT r.student_id
    FROM exam_registration r
   WHERE r.exam_id = p_exam_id AND r.status = 'REGISTERED'
   GROUP BY r.student_id
  HAVING MIN(fn_attendance_percentage(r.student_id, r.offering_id)) >= v_min
     AND fn_student_fee_due(r.student_id, 'EXAM', 0) = 0;

  SELECT COUNT(DISTINCT r.student_id) - (SELECT COUNT(*) FROM tmp_eligible) INTO v_skipped
    FROM exam_registration r WHERE r.exam_id = p_exam_id AND r.status = 'REGISTERED';
  SELECT COUNT(*) INTO v_offset FROM hall_ticket WHERE exam_id = p_exam_id;

  START TRANSACTION;
    INSERT INTO hall_ticket (hall_ticket_no, exam_id, student_id, seat_no)
    SELECT CONCAT('HT-', p_exam_id, '-', LPAD(v_offset + n, 4, '0')), p_exam_id, student_id,
           CONCAT('S', LPAD(v_offset + n, 4, '0'))
      FROM (SELECT e.student_id, ROW_NUMBER() OVER (ORDER BY e.student_id) AS n
              FROM tmp_eligible e
             WHERE NOT EXISTS (SELECT 1 FROM hall_ticket h WHERE h.exam_id = p_exam_id AND h.student_id = e.student_id)) x;
    SET v_issued = ROW_COUNT();
  COMMIT;
  DROP TEMPORARY TABLE IF EXISTS tmp_eligible;
  SELECT v_issued AS hall_tickets_issued, v_skipped AS registered_but_ineligible;
END$$

-- Converts marks to grades: for every course scheduled in the exam, the marks of ALL exams of that
-- semester (ISE + MSE + ESE ...) are added up, the percentage is looked up in grade_scale and stored in
-- `result`. Absent counts as 0. Re-runnable (results of those courses are rebuilt).
CREATE PROCEDURE sp_publish_results(IN p_exam_id VARCHAR(12))
BEGIN
  DECLARE v_sem INT UNSIGNED;
  DECLARE v_rows INT DEFAULT 0;
  DECLARE v_pass INT DEFAULT 0;
  DECLARE v_fail INT DEFAULT 0;
  DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; RESIGNAL; END;

  SELECT semester_id INTO v_sem FROM exam WHERE exam_id = p_exam_id;
  IF v_sem IS NULL THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Unknown exam_id';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM marks WHERE exam_id = p_exam_id) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'No marks have been entered for this exam';
  END IF;

  START TRANSACTION;
    DELETE r FROM result r
     WHERE r.offering_id IN (SELECT offering_id FROM exam_schedule WHERE exam_id = p_exam_id)
       AND r.student_id  IN (SELECT student_id FROM marks WHERE exam_id = p_exam_id);

    INSERT INTO result (student_id, offering_id, total_marks, max_marks, grade)
    SELECT t.student_id, t.offering_id, t.total, t.max_total,
           (SELECT g.grade FROM grade_scale g
             WHERE g.min_pct <= ROUND(t.total * 100 / t.max_total, 2)
             ORDER BY g.min_pct DESC LIMIT 1)
      FROM (SELECT m.student_id, m.offering_id,
                   SUM(IFNULL(m.marks_obtained, 0)) AS total,
                   SUM(es.max_marks)                AS max_total
              FROM marks m
              JOIN exam_schedule es ON es.exam_id = m.exam_id AND es.offering_id = m.offering_id
              JOIN exam e           ON e.exam_id = m.exam_id AND e.semester_id = v_sem
             WHERE m.offering_id IN (SELECT offering_id FROM exam_schedule WHERE exam_id = p_exam_id)
               AND m.student_id  IN (SELECT student_id FROM marks WHERE exam_id = p_exam_id)
             GROUP BY m.student_id, m.offering_id) t;
    SET v_rows = ROW_COUNT();

    UPDATE exam SET status = 'RESULTS_PUBLISHED' WHERE exam_id = p_exam_id;
    SELECT SUM(g.is_pass = 1), SUM(g.is_pass = 0) INTO v_pass, v_fail
      FROM result r JOIN grade_scale g ON g.grade = r.grade
     WHERE r.offering_id IN (SELECT offering_id FROM exam_schedule WHERE exam_id = p_exam_id)
       AND r.student_id  IN (SELECT student_id FROM marks WHERE exam_id = p_exam_id);
  COMMIT;
  SELECT v_rows AS results_published, IFNULL(v_pass, 0) AS passed, IFNULL(v_fail, 0) AS failed;
END$$

DELIMITER ;

-- Rank list: RANK() of students by CGPA inside program and semester.
CREATE VIEW vw_rank_list AS
SELECT t.program_id,
       t.semester_id,
       ay.label        AS academic_year,
       sm.term,
       t.student_id,
       t.full_name,
       t.credits,
       t.sgpa,
       t.cgpa,
       RANK() OVER (PARTITION BY t.program_id, t.semester_id ORDER BY t.cgpa DESC) AS rank_in_program
  FROM (SELECT s.program_id, o.semester_id, s.student_id, s.full_name,
               SUM(c.credits)                                             AS credits,
               ROUND(SUM(c.credits * g.grade_point) / SUM(c.credits), 2)  AS sgpa,
               fn_calculate_cgpa(s.student_id)                            AS cgpa
          FROM result r
          JOIN student s         ON s.student_id  = r.student_id
          JOIN course_offering o ON o.offering_id = r.offering_id
          JOIN course c          ON c.course_code = o.course_code
          JOIN grade_scale g     ON g.grade       = r.grade
         GROUP BY s.program_id, o.semester_id, s.student_id, s.full_name) t
  JOIN semester sm      ON sm.semester_id = t.semester_id
  JOIN academic_year ay ON ay.academic_year_id = sm.academic_year_id;
