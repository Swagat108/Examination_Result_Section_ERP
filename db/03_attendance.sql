-- =====================================================================
-- 03_attendance.sql   |  G4 - Attendance Management
-- class_session, student_attendance, faculty_attendance, leave_type,
-- leave_application, leave_balance.
-- Depends on: 00_admin (app_setting), 01_academics (employee, course_offering, classroom),
--             02_students (student, course_enrollment, semester_registration)
-- Provides:   fn_attendance_percentage -> G2 (exam eligibility)
--             approved leave_application -> G5 (payroll)
-- =====================================================================
SET NAMES utf8mb4;

CREATE TABLE class_session (
  session_id   INT UNSIGNED NOT NULL AUTO_INCREMENT,
  offering_id  INT UNSIGNED NOT NULL,
  session_date DATE         NOT NULL,
  start_time   TIME         NOT NULL,
  end_time     TIME         NOT NULL,
  session_type ENUM('LECTURE','LAB','TUTORIAL') NOT NULL DEFAULT 'LECTURE',
  batch_id     INT UNSIGNED NULL COMMENT 'set for batch-wise practicals',
  batch_key    INT UNSIGNED GENERATED ALWAYS AS (IFNULL(batch_id, 0)) STORED,
  conducted_by CHAR(7)      NULL,
  classroom_id INT UNSIGNED NULL,
  topic        VARCHAR(200) NULL,
  status       ENUM('SCHEDULED','HELD','CANCELLED') NOT NULL DEFAULT 'HELD',
  created_at   TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at   TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT pk_class_session PRIMARY KEY (session_id),
  CONSTRAINT uq_class_session UNIQUE (offering_id, session_date, start_time, batch_key),
  CONSTRAINT fk_session_offering  FOREIGN KEY (offering_id)  REFERENCES course_offering (offering_id),
  CONSTRAINT fk_session_batch     FOREIGN KEY (batch_id)     REFERENCES batch (batch_id),
  CONSTRAINT fk_session_employee  FOREIGN KEY (conducted_by) REFERENCES employee (employee_id),
  CONSTRAINT fk_session_classroom FOREIGN KEY (classroom_id) REFERENCES classroom (classroom_id),
  CONSTRAINT ck_session_times CHECK (end_time > start_time),
  KEY ix_session_date (session_date)
) ENGINE=InnoDB COMMENT='G4: one lecture / lab held (or planned) for an offering';

CREATE TABLE student_attendance (
  attendance_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  session_id    INT UNSIGNED    NOT NULL,
  student_id    CHAR(11)        NOT NULL,
  status        ENUM('PRESENT','ABSENT','LATE') NOT NULL DEFAULT 'PRESENT',
  marked_by     CHAR(7)         NULL,
  created_at    TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at    TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT pk_student_attendance PRIMARY KEY (attendance_id),
  CONSTRAINT uq_student_attendance UNIQUE (session_id, student_id),
  CONSTRAINT fk_sattendance_session  FOREIGN KEY (session_id) REFERENCES class_session (session_id) ON DELETE CASCADE,
  CONSTRAINT fk_sattendance_student  FOREIGN KEY (student_id) REFERENCES student (student_id),
  CONSTRAINT fk_sattendance_marker   FOREIGN KEY (marked_by)  REFERENCES employee (employee_id),
  KEY ix_sattendance_student (student_id, status)
) ENGINE=InnoDB COMMENT='G4: PRESENT / LATE count as attended, ABSENT does not';

CREATE TABLE faculty_attendance (
  faculty_attendance_id INT UNSIGNED NOT NULL AUTO_INCREMENT,
  employee_id     CHAR(7)      NOT NULL,
  attendance_date DATE         NOT NULL,
  status          ENUM('PRESENT','ABSENT','ON_LEAVE','HALF_DAY') NOT NULL DEFAULT 'PRESENT',
  check_in        TIME         NULL,
  check_out       TIME         NULL,
  created_at      TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at      TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT pk_faculty_attendance PRIMARY KEY (faculty_attendance_id),
  CONSTRAINT uq_faculty_attendance UNIQUE (employee_id, attendance_date),
  CONSTRAINT fk_fattendance_employee FOREIGN KEY (employee_id) REFERENCES employee (employee_id),
  CONSTRAINT ck_fattendance_times CHECK (check_in IS NULL OR check_out IS NULL OR check_out > check_in)
) ENGINE=InnoDB COMMENT='G4: daily faculty / staff attendance';

CREATE TABLE leave_type (
  leave_type_id TINYINT UNSIGNED NOT NULL AUTO_INCREMENT,
  leave_code    VARCHAR(5)       NOT NULL COMMENT 'CL, EL, ML, LWP',
  leave_name    VARCHAR(60)      NOT NULL,
  annual_quota  DECIMAL(4,1)     NULL COMMENT 'NULL = no quota (unpaid leave)',
  is_paid       TINYINT(1)       NOT NULL DEFAULT 1,
  created_at    TIMESTAMP        NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at    TIMESTAMP        NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT pk_leave_type PRIMARY KEY (leave_type_id),
  CONSTRAINT uq_leave_type_code UNIQUE (leave_code),
  CONSTRAINT ck_leave_type_quota CHECK (annual_quota IS NULL OR annual_quota >= 0)
) ENGINE=InnoDB COMMENT='G4: casual, earned, medical, leave without pay';

CREATE TABLE leave_application (
  leave_application_id INT UNSIGNED NOT NULL AUTO_INCREMENT,
  employee_id   CHAR(7)          NOT NULL,
  leave_type_id TINYINT UNSIGNED NOT NULL,
  from_date     DATE             NOT NULL,
  to_date       DATE             NOT NULL,
  total_days    SMALLINT         GENERATED ALWAYS AS (DATEDIFF(to_date, from_date) + 1) STORED,
  reason        VARCHAR(300)     NULL,
  status        ENUM('PENDING','APPROVED','REJECTED','CANCELLED') NOT NULL DEFAULT 'PENDING',
  applied_on    DATE             NOT NULL DEFAULT (CURRENT_DATE),
  decided_by    CHAR(7)          NULL,
  decided_on    DATE             NULL,
  remarks       VARCHAR(200)     NULL,
  created_at    TIMESTAMP        NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at    TIMESTAMP        NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT pk_leave_application PRIMARY KEY (leave_application_id),
  CONSTRAINT fk_leave_employee FOREIGN KEY (employee_id)   REFERENCES employee (employee_id),
  CONSTRAINT fk_leave_type     FOREIGN KEY (leave_type_id) REFERENCES leave_type (leave_type_id),
  CONSTRAINT fk_leave_decider  FOREIGN KEY (decided_by)    REFERENCES employee (employee_id),
  CONSTRAINT ck_leave_dates    CHECK (to_date >= from_date),
  KEY ix_leave_employee (employee_id, status, from_date)
) ENGINE=InnoDB COMMENT='G4: leave requests; approval is handled by trg_leave_approval';

CREATE TABLE leave_balance (
  leave_balance_id INT UNSIGNED     NOT NULL AUTO_INCREMENT,
  employee_id      CHAR(7)          NOT NULL,
  leave_type_id    TINYINT UNSIGNED NOT NULL,
  leave_year       SMALLINT UNSIGNED NOT NULL,
  allocated        DECIMAL(4,1)     NOT NULL,
  used             DECIMAL(4,1)     NOT NULL DEFAULT 0,
  balance          DECIMAL(4,1)     GENERATED ALWAYS AS (allocated - used) STORED,
  created_at       TIMESTAMP        NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at       TIMESTAMP        NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT pk_leave_balance PRIMARY KEY (leave_balance_id),
  CONSTRAINT uq_leave_balance UNIQUE (employee_id, leave_type_id, leave_year),
  CONSTRAINT fk_lbalance_employee FOREIGN KEY (employee_id)   REFERENCES employee (employee_id),
  CONSTRAINT fk_lbalance_type     FOREIGN KEY (leave_type_id) REFERENCES leave_type (leave_type_id),
  CONSTRAINT ck_lbalance_year CHECK (leave_year BETWEEN 2000 AND 2100),
  CONSTRAINT ck_lbalance_used CHECK (allocated >= 0 AND used >= 0 AND used <= allocated)
) ENGINE=InnoDB COMMENT='G4: yearly leave entitlement and consumption per employee';

-- ---------------------------------------------------------------------
-- SQL OBJECTS
-- ---------------------------------------------------------------------
DELIMITER $$

-- Attendance % of a student in one course offering (PRESENT + LATE over sessions HELD).
-- Returns 100.00 while no session has been recorded, so nobody is a "defaulter" before classes start.
CREATE FUNCTION fn_attendance_percentage(p_student_id CHAR(11), p_offering_id INT UNSIGNED)
  RETURNS DECIMAL(5,2)
  READS SQL DATA
BEGIN
  DECLARE v_total INT DEFAULT 0;
  DECLARE v_attended INT DEFAULT 0;
  SELECT COUNT(*), IFNULL(SUM(sa.status IN ('PRESENT','LATE')), 0)
    INTO v_total, v_attended
    FROM student_attendance sa
    JOIN class_session cs ON cs.session_id = sa.session_id AND cs.status = 'HELD'
   WHERE sa.student_id = p_student_id AND cs.offering_id = p_offering_id;
  IF v_total = 0 THEN
    RETURN 100.00;
  END IF;
  RETURN ROUND(v_attended * 100 / v_total, 2);
END$$

-- Marks the whole class PRESENT, then flips the absentees, in one transaction.
--   p_absent_list: JSON array of student ids, e.g. '["2024ETC0362","2024ETC0209"]' (or '[]')
-- The roster is the students enrolled in the offering (and in the session's batch for practicals).
CREATE PROCEDURE sp_mark_attendance_bulk(
  IN p_session_id  INT UNSIGNED,
  IN p_absent_list JSON,
  IN p_marked_by   CHAR(7))
BEGIN
  DECLARE v_offering INT UNSIGNED;
  DECLARE v_batch    INT UNSIGNED;
  DECLARE v_sem      INT UNSIGNED;
  DECLARE v_status   VARCHAR(10);
  DECLARE v_present  INT DEFAULT 0;
  DECLARE v_absent   INT DEFAULT 0;
  DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; RESIGNAL; END;

  SELECT cs.offering_id, cs.batch_id, o.semester_id, cs.status
    INTO v_offering, v_batch, v_sem, v_status
    FROM class_session cs JOIN course_offering o ON o.offering_id = cs.offering_id
   WHERE cs.session_id = p_session_id;
  IF v_offering IS NULL THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Unknown session_id';
  END IF;
  IF v_status = 'CANCELLED' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Cannot mark attendance for a cancelled session';
  END IF;
  IF p_absent_list IS NULL OR NOT JSON_VALID(p_absent_list) OR JSON_TYPE(p_absent_list) <> 'ARRAY' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'p_absent_list must be a JSON array of student ids';
  END IF;

  -- roster for this session
  CREATE TEMPORARY TABLE IF NOT EXISTS tmp_roster (student_id CHAR(11) NOT NULL PRIMARY KEY);
  DELETE FROM tmp_roster;
  INSERT INTO tmp_roster (student_id)
  SELECT ce.student_id
    FROM course_enrollment ce
    LEFT JOIN semester_registration sr ON sr.student_id = ce.student_id AND sr.semester_id = v_sem
   WHERE ce.offering_id = v_offering AND ce.status = 'ENROLLED'
     AND (v_batch IS NULL OR sr.batch_id = v_batch);

  -- every absentee must be on the roster
  IF EXISTS (SELECT 1
               FROM JSON_TABLE(p_absent_list, '$[*]' COLUMNS (sid CHAR(11) PATH '$')) j
              WHERE j.sid NOT IN (SELECT student_id FROM tmp_roster)) THEN
    DROP TEMPORARY TABLE tmp_roster;
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Absent list contains a student who is not enrolled in this session';
  END IF;

  START TRANSACTION;
    DELETE FROM student_attendance WHERE session_id = p_session_id;
    INSERT INTO student_attendance (session_id, student_id, status, marked_by)
    SELECT p_session_id, student_id, 'PRESENT', p_marked_by FROM tmp_roster;
    SET v_present = ROW_COUNT();
    UPDATE student_attendance sa
       SET sa.status = 'ABSENT'
     WHERE sa.session_id = p_session_id
       AND sa.student_id IN (SELECT j.sid FROM JSON_TABLE(p_absent_list, '$[*]' COLUMNS (sid CHAR(11) PATH '$')) j);
    SET v_absent = ROW_COUNT();
    UPDATE class_session SET status = 'HELD' WHERE session_id = p_session_id AND status = 'SCHEDULED';
  COMMIT;
  DROP TEMPORARY TABLE IF EXISTS tmp_roster;

  SELECT v_present - v_absent AS present, v_absent AS absent, v_present AS roster_size;
END$$

-- Remaining leave days of an employee for a leave type (e.g. 'CL') in the current calendar year.
CREATE FUNCTION fn_leave_balance(p_employee_id CHAR(7), p_leave_code VARCHAR(5)) RETURNS DECIMAL(4,1)
  READS SQL DATA
BEGIN
  DECLARE v_balance DECIMAL(4,1);
  SELECT lb.balance INTO v_balance
    FROM leave_balance lb JOIN leave_type lt ON lt.leave_type_id = lb.leave_type_id
   WHERE lb.employee_id = p_employee_id AND lt.leave_code = p_leave_code
     AND lb.leave_year = YEAR(CURDATE());
  RETURN IFNULL(v_balance, 0);
END$$

-- Approval deducts the days from leave_balance (paid leave types) and is rejected when the
-- balance is too low; cancelling an approved leave gives the days back.
CREATE TRIGGER trg_leave_approval AFTER UPDATE ON leave_application
FOR EACH ROW
BEGIN
  DECLARE v_paid TINYINT(1);
  DECLARE v_days SMALLINT;
  SET v_days = DATEDIFF(NEW.to_date, NEW.from_date) + 1;
  SELECT is_paid INTO v_paid FROM leave_type WHERE leave_type_id = NEW.leave_type_id;

  IF OLD.status <> 'APPROVED' AND NEW.status = 'APPROVED' AND v_paid = 1 THEN
    UPDATE leave_balance
       SET used = used + v_days
     WHERE employee_id = NEW.employee_id AND leave_type_id = NEW.leave_type_id
       AND leave_year = YEAR(NEW.from_date) AND balance >= v_days;
    IF ROW_COUNT() = 0 THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Insufficient leave balance - leave cannot be approved';
    END IF;
  ELSEIF OLD.status = 'APPROVED' AND NEW.status = 'CANCELLED' AND v_paid = 1 THEN
    UPDATE leave_balance
       SET used = GREATEST(used - v_days, 0)
     WHERE employee_id = NEW.employee_id AND leave_type_id = NEW.leave_type_id
       AND leave_year = YEAR(NEW.from_date);
  END IF;
END$$

DELIMITER ;

-- Students below the minimum attendance (app_setting min_attendance_pct, 75) in any course.
CREATE VIEW vw_attendance_defaulters AS
SELECT s.student_id,
       s.full_name,
       c.course_code,
       c.course_title,
       o.offering_id,
       COUNT(*)                                       AS sessions_held,
       SUM(sa.status IN ('PRESENT','LATE'))           AS sessions_attended,
       ROUND(100 * SUM(sa.status IN ('PRESENT','LATE')) / COUNT(*), 2) AS attendance_pct
  FROM student_attendance sa
  JOIN class_session   cs ON cs.session_id = sa.session_id AND cs.status = 'HELD'
  JOIN course_offering o  ON o.offering_id = cs.offering_id
  JOIN course          c  ON c.course_code = o.course_code
  JOIN student         s  ON s.student_id  = sa.student_id
 GROUP BY s.student_id, s.full_name, c.course_code, c.course_title, o.offering_id
HAVING 100 * SUM(sa.status IN ('PRESENT','LATE')) / COUNT(*) < fn_setting_num('min_attendance_pct');
