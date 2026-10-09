-- =====================================================================
-- 00_admin.sql   |  G1 - Communication & Administration
-- Master data (department, program, academic_year, semester, division,
-- batch), login/roles, notices, grievances, app settings.
-- Run first: every other module references these tables.
-- The target database is selected by the caller (db/rebuild.sh|ps1).
-- Cross-module FKs on app_user (student / employee) are added in
-- 07_integration.sql once those tables exist.
-- =====================================================================
SET NAMES utf8mb4;

-- ---------------------------------------------------------------------
-- TABLES
-- ---------------------------------------------------------------------

CREATE TABLE department (
  dept_code        CHAR(3)       NOT NULL,
  dept_name        VARCHAR(100)  NOT NULL,
  dept_type        ENUM('ACADEMIC','ADMINISTRATIVE') NOT NULL DEFAULT 'ACADEMIC',
  hod_employee_id  CHAR(7)       NULL COMMENT 'FK to employee added in 01_academics.sql',
  established_year YEAR          NULL,
  created_at       TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at       TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT pk_department      PRIMARY KEY (dept_code),
  CONSTRAINT uq_department_name UNIQUE (dept_name),
  CONSTRAINT ck_department_code CHECK (dept_code REGEXP '^[A-Z]{3}$')
) ENGINE=InnoDB COMMENT='G1 master: departments (ETC, CMP, ITX, ...)';

CREATE TABLE program (
  program_id        INT UNSIGNED     NOT NULL AUTO_INCREMENT,
  dept_code         CHAR(3)          NOT NULL,
  program_code      VARCHAR(12)      NOT NULL,
  program_name      VARCHAR(120)     NOT NULL,
  degree_level      ENUM('DIPLOMA','UG','PG','DOCTORAL') NOT NULL DEFAULT 'UG',
  duration_years    TINYINT UNSIGNED NOT NULL,
  total_semesters   TINYINT UNSIGNED NOT NULL,
  sanctioned_intake SMALLINT UNSIGNED NULL,
  created_at        TIMESTAMP        NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at        TIMESTAMP        NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT pk_program      PRIMARY KEY (program_id),
  CONSTRAINT uq_program_code UNIQUE (program_code),
  CONSTRAINT fk_program_dept FOREIGN KEY (dept_code) REFERENCES department (dept_code),
  CONSTRAINT ck_program_duration  CHECK (duration_years BETWEEN 1 AND 6),
  CONSTRAINT ck_program_semesters CHECK (total_semesters = duration_years * 2),
  CONSTRAINT ck_program_intake    CHECK (sanctioned_intake IS NULL OR sanctioned_intake > 0)
) ENGINE=InnoDB COMMENT='G1 master: degree programs offered by a department';

CREATE TABLE academic_year (
  academic_year_id INT UNSIGNED NOT NULL AUTO_INCREMENT,
  label            VARCHAR(9)   NOT NULL COMMENT 'e.g. 2026-27',
  start_date       DATE         NOT NULL,
  end_date         DATE         NOT NULL,
  is_current       TINYINT(1)   NOT NULL DEFAULT 0,
  current_flag     TINYINT      GENERATED ALWAYS AS (IF(is_current = 1, 1, NULL)) STORED,
  created_at       TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at       TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT pk_academic_year PRIMARY KEY (academic_year_id),
  CONSTRAINT uq_academic_year_label UNIQUE (label),
  CONSTRAINT uq_academic_year_current UNIQUE (current_flag),            -- at most one current year
  CONSTRAINT ck_academic_year_label CHECK (label REGEXP '^[0-9]{4}-[0-9]{2}$'),
  CONSTRAINT ck_academic_year_dates CHECK (end_date > start_date)
) ENGINE=InnoDB COMMENT='G1 master: academic years';

CREATE TABLE semester (
  semester_id      INT UNSIGNED NOT NULL AUTO_INCREMENT,
  academic_year_id INT UNSIGNED NOT NULL,
  term             ENUM('ODD','EVEN') NOT NULL COMMENT 'ODD = Sem 1/3/5/7, EVEN = Sem 2/4/6/8',
  start_date       DATE         NOT NULL,
  end_date         DATE         NOT NULL,
  is_active        TINYINT(1)   NOT NULL DEFAULT 0,
  active_flag      TINYINT      GENERATED ALWAYS AS (IF(is_active = 1, 1, NULL)) STORED,
  created_at       TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at       TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT pk_semester PRIMARY KEY (semester_id),
  CONSTRAINT uq_semester_term UNIQUE (academic_year_id, term),
  CONSTRAINT uq_semester_active UNIQUE (active_flag),                    -- at most one active term
  CONSTRAINT fk_semester_ay FOREIGN KEY (academic_year_id) REFERENCES academic_year (academic_year_id),
  CONSTRAINT ck_semester_dates CHECK (end_date > start_date)
) ENGINE=InnoDB COMMENT='G1 master: a teaching term (odd/even) inside an academic year';

CREATE TABLE division (
  division_id      INT UNSIGNED     NOT NULL AUTO_INCREMENT,
  program_id       INT UNSIGNED     NOT NULL,
  academic_year_id INT UNSIGNED     NOT NULL,
  year_of_study    TINYINT UNSIGNED NOT NULL COMMENT '1=FY 2=SY 3=TY 4=Final',
  division_name    VARCHAR(20)      NOT NULL COMMENT 'e.g. TY V',
  created_at       TIMESTAMP        NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at       TIMESTAMP        NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT pk_division PRIMARY KEY (division_id),
  CONSTRAINT uq_division UNIQUE (program_id, academic_year_id, division_name),
  CONSTRAINT fk_division_program FOREIGN KEY (program_id) REFERENCES program (program_id),
  CONSTRAINT fk_division_ay      FOREIGN KEY (academic_year_id) REFERENCES academic_year (academic_year_id),
  CONSTRAINT ck_division_year    CHECK (year_of_study BETWEEN 1 AND 6)
) ENGINE=InnoDB COMMENT='G1 master: class division of a program in an academic year';

CREATE TABLE batch (
  batch_id    INT UNSIGNED NOT NULL AUTO_INCREMENT,
  division_id INT UNSIGNED NOT NULL,
  batch_code  VARCHAR(5)   NOT NULL COMMENT 'practical batch, e.g. K5',
  created_at  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT pk_batch PRIMARY KEY (batch_id),
  CONSTRAINT uq_batch UNIQUE (division_id, batch_code),
  CONSTRAINT fk_batch_division FOREIGN KEY (division_id) REFERENCES division (division_id)
) ENGINE=InnoDB COMMENT='G1 master: practical/lab batch inside a division';

CREATE TABLE role (
  role_id     TINYINT UNSIGNED NOT NULL AUTO_INCREMENT,
  role_name   VARCHAR(30)      NOT NULL,
  description VARCHAR(200)     NULL,
  created_at  TIMESTAMP        NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at  TIMESTAMP        NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT pk_role PRIMARY KEY (role_id),
  CONSTRAINT uq_role_name UNIQUE (role_name),
  CONSTRAINT ck_role_name CHECK (role_name REGEXP '^[A-Z_]+$')
) ENGINE=InnoDB COMMENT='G1: ADMIN, FACULTY, STUDENT, ACCOUNTANT, PLACEMENT_OFFICER';

CREATE TABLE app_user (
  user_id       INT UNSIGNED NOT NULL AUTO_INCREMENT,
  username      VARCHAR(50)  NOT NULL,
  email         VARCHAR(120) NOT NULL,
  password_hash VARCHAR(255) NOT NULL COMMENT 'bcrypt hash - the backend hashes, SQL never sees plain text',
  student_id    CHAR(11)     NULL COMMENT 'FK to student added in 07_integration.sql',
  employee_id   CHAR(7)      NULL COMMENT 'FK to employee added in 07_integration.sql',
  is_active     TINYINT(1)   NOT NULL DEFAULT 1,
  last_login_at TIMESTAMP    NULL,
  created_at    TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at    TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT pk_app_user PRIMARY KEY (user_id),
  CONSTRAINT uq_app_user_username UNIQUE (username),
  CONSTRAINT uq_app_user_email    UNIQUE (email),
  CONSTRAINT uq_app_user_student  UNIQUE (student_id),                   -- one login per person
  CONSTRAINT uq_app_user_employee UNIQUE (employee_id),
  CONSTRAINT ck_app_user_email    CHECK (email REGEXP '^[^@ ]+@[^@ ]+$'),
  CONSTRAINT ck_app_user_one_ref  CHECK (student_id IS NULL OR employee_id IS NULL)
) ENGINE=InnoDB COMMENT='G1: login accounts (JWT auth in the backend)';

CREATE TABLE user_role (
  user_id     INT UNSIGNED     NOT NULL,
  role_id     TINYINT UNSIGNED NOT NULL,
  assigned_by INT UNSIGNED     NULL,
  created_at  TIMESTAMP        NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at  TIMESTAMP        NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT pk_user_role PRIMARY KEY (user_id, role_id),
  CONSTRAINT fk_user_role_user FOREIGN KEY (user_id)     REFERENCES app_user (user_id) ON DELETE CASCADE,
  CONSTRAINT fk_user_role_role FOREIGN KEY (role_id)     REFERENCES role (role_id),
  CONSTRAINT fk_user_role_by   FOREIGN KEY (assigned_by) REFERENCES app_user (user_id) ON DELETE SET NULL
) ENGINE=InnoDB COMMENT='G1: many-to-many user <-> role';

CREATE TABLE user_audit_log (
  audit_id   BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  user_id    INT UNSIGNED    NOT NULL,
  action     ENUM('ROLE_ASSIGNED','ROLE_REVOKED','DEACTIVATED','REACTIVATED') NOT NULL,
  old_value  VARCHAR(100)    NULL,
  new_value  VARCHAR(100)    NULL,
  changed_by VARCHAR(100)    NOT NULL COMMENT '@app_user set by the backend, else the MySQL account',
  created_at TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT pk_user_audit_log PRIMARY KEY (audit_id),
  CONSTRAINT fk_user_audit_user FOREIGN KEY (user_id) REFERENCES app_user (user_id),
  KEY ix_user_audit_user (user_id, created_at)
) ENGINE=InnoDB COMMENT='G1: filled by trg_user_audit, trg_user_role_audit_ins/_del';

CREATE TABLE app_setting (
  setting_key   VARCHAR(50)  NOT NULL,
  setting_value VARCHAR(100) NOT NULL,
  description   VARCHAR(200) NULL,
  created_at    TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at    TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT pk_app_setting PRIMARY KEY (setting_key)
) ENGINE=InnoDB COMMENT='G1: business thresholds used by SQL objects (75% attendance, 7 day escalation, ...)';

CREATE TABLE notice (
  notice_id    INT UNSIGNED NOT NULL AUTO_INCREMENT,
  title        VARCHAR(200) NOT NULL,
  body         TEXT         NOT NULL,
  posted_by    INT UNSIGNED NOT NULL,
  priority     ENUM('LOW','NORMAL','HIGH','URGENT') NOT NULL DEFAULT 'NORMAL',
  published_at DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  expires_at   DATETIME     NULL,
  is_active    TINYINT(1)   NOT NULL DEFAULT 1,
  created_at   TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at   TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT pk_notice PRIMARY KEY (notice_id),
  CONSTRAINT fk_notice_user FOREIGN KEY (posted_by) REFERENCES app_user (user_id),
  CONSTRAINT ck_notice_expiry CHECK (expires_at IS NULL OR expires_at > published_at),
  KEY ix_notice_published (published_at)
) ENGINE=InnoDB COMMENT='G1: notice board';

CREATE TABLE notice_target (
  notice_target_id INT UNSIGNED     NOT NULL AUTO_INCREMENT,
  notice_id        INT UNSIGNED     NOT NULL,
  role_id          TINYINT UNSIGNED NULL COMMENT 'NULL = every role',
  dept_code        CHAR(3)          NULL COMMENT 'NULL = every department',
  created_at       TIMESTAMP        NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at       TIMESTAMP        NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT pk_notice_target PRIMARY KEY (notice_target_id),
  CONSTRAINT fk_notice_target_notice FOREIGN KEY (notice_id) REFERENCES notice (notice_id) ON DELETE CASCADE,
  CONSTRAINT fk_notice_target_role   FOREIGN KEY (role_id)   REFERENCES role (role_id),
  CONSTRAINT fk_notice_target_dept   FOREIGN KEY (dept_code) REFERENCES department (dept_code)
) ENGINE=InnoDB COMMENT='G1: who a notice is for (role x department)';

CREATE TABLE grievance (
  grievance_id       INT UNSIGNED NOT NULL AUTO_INCREMENT,
  raised_by          INT UNSIGNED NOT NULL,
  category           ENUM('ACADEMIC','FEES','HOSTEL','EXAM','ADMINISTRATION','OTHER') NOT NULL DEFAULT 'OTHER',
  subject            VARCHAR(200) NOT NULL,
  description        TEXT         NOT NULL,
  status             ENUM('OPEN','IN_PROGRESS','ESCALATED','RESOLVED','CLOSED') NOT NULL DEFAULT 'OPEN',
  assigned_to        INT UNSIGNED NULL,
  escalated_at       DATETIME     NULL,
  resolved_at        DATETIME     NULL,
  resolution_remarks VARCHAR(500) NULL,
  created_at         TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at         TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT pk_grievance PRIMARY KEY (grievance_id),
  CONSTRAINT fk_grievance_raised   FOREIGN KEY (raised_by)   REFERENCES app_user (user_id),
  CONSTRAINT fk_grievance_assigned FOREIGN KEY (assigned_to) REFERENCES app_user (user_id),
  CONSTRAINT ck_grievance_resolved CHECK (status NOT IN ('RESOLVED','CLOSED') OR resolved_at IS NOT NULL),
  KEY ix_grievance_status (status, created_at)
) ENGINE=InnoDB COMMENT='G1: grievance portal';

-- ---------------------------------------------------------------------
-- FUNCTIONS
-- ---------------------------------------------------------------------
DELIMITER $$

-- Numeric business setting (75 attendance %, 7 escalation days, ...). NULL if the key is missing.
CREATE FUNCTION fn_setting_num(p_key VARCHAR(50)) RETURNS DECIMAL(12,2)
  READS SQL DATA
BEGIN
  DECLARE v_val DECIMAL(12,2);
  SELECT CAST(setting_value AS DECIMAL(12,2)) INTO v_val FROM app_setting WHERE setting_key = p_key;
  RETURN v_val;
END$$

-- The active teaching term. Uses the is_active flag; falls back to the term containing today.
CREATE FUNCTION fn_current_semester() RETURNS INT UNSIGNED
  READS SQL DATA
BEGIN
  DECLARE v_id INT UNSIGNED;
  SELECT semester_id INTO v_id FROM semester WHERE is_active = 1 LIMIT 1;
  IF v_id IS NULL THEN
    SELECT semester_id INTO v_id FROM semester
     WHERE CURDATE() BETWEEN start_date AND end_date
     ORDER BY start_date DESC LIMIT 1;
  END IF;
  RETURN v_id;
END$$

-- ---------------------------------------------------------------------
-- PROCEDURES
-- ---------------------------------------------------------------------

-- Creates a login account and its role mapping atomically.
-- p_ref_id: student_id for STUDENT, employee_id for FACULTY/ACCOUNTANT/PLACEMENT_OFFICER, NULL allowed for ADMIN.
-- (Extra p_password_hash vs. the plan: app_user.password_hash is NOT NULL and the backend does the bcrypt.)
CREATE PROCEDURE sp_create_user_with_role(
  IN  p_username      VARCHAR(50),
  IN  p_email         VARCHAR(120),
  IN  p_password_hash VARCHAR(255),
  IN  p_role_name     VARCHAR(30),
  IN  p_ref_id        VARCHAR(11),
  OUT p_user_id       INT UNSIGNED)
BEGIN
  DECLARE v_role_id    TINYINT UNSIGNED;
  DECLARE v_student    CHAR(11) DEFAULT NULL;
  DECLARE v_employee   CHAR(7)  DEFAULT NULL;
  DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; RESIGNAL; END;

  SELECT role_id INTO v_role_id FROM role WHERE role_name = p_role_name;
  IF v_role_id IS NULL THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Unknown role';
  END IF;

  IF p_role_name = 'STUDENT' THEN
    IF p_ref_id IS NULL OR NOT EXISTS (SELECT 1 FROM student WHERE student_id = p_ref_id) THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'STUDENT role needs an existing student_id';
    END IF;
    SET v_student = p_ref_id;
  ELSEIF p_ref_id IS NOT NULL THEN
    IF NOT EXISTS (SELECT 1 FROM employee WHERE employee_id = p_ref_id) THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'employee_id does not exist';
    END IF;
    SET v_employee = p_ref_id;
  END IF;

  START TRANSACTION;
    INSERT INTO app_user (username, email, password_hash, student_id, employee_id)
    VALUES (p_username, p_email, p_password_hash, v_student, v_employee);
    SET p_user_id = LAST_INSERT_ID();
    INSERT INTO user_role (user_id, role_id) VALUES (p_user_id, v_role_id);
  COMMIT;
END$$

-- Publishes a notice and targets it by role and/or department (NULL = everyone).
CREATE PROCEDURE sp_publish_notice(
  IN  p_title     VARCHAR(200),
  IN  p_body      TEXT,
  IN  p_role_name VARCHAR(30),
  IN  p_dept_code CHAR(3),
  IN  p_posted_by INT UNSIGNED,
  OUT p_notice_id INT UNSIGNED)
BEGIN
  DECLARE v_role_id TINYINT UNSIGNED DEFAULT NULL;
  DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; RESIGNAL; END;

  IF p_role_name IS NOT NULL THEN
    SELECT role_id INTO v_role_id FROM role WHERE role_name = p_role_name;
    IF v_role_id IS NULL THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Unknown role';
    END IF;
  END IF;
  IF p_dept_code IS NOT NULL AND NOT EXISTS (SELECT 1 FROM department WHERE dept_code = p_dept_code) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Unknown department';
  END IF;

  START TRANSACTION;
    INSERT INTO notice (title, body, posted_by) VALUES (p_title, p_body, p_posted_by);
    SET p_notice_id = LAST_INSERT_ID();
    INSERT INTO notice_target (notice_id, role_id, dept_code) VALUES (p_notice_id, v_role_id, p_dept_code);
  COMMIT;
END$$

-- Escalates every grievance that has been unresolved for >= grievance_escalation_days.
-- The UPDATE only touches updated_at; trg_grievance_escalation decides and flips the status.
CREATE PROCEDURE sp_escalate_overdue_grievances()
BEGIN
  UPDATE grievance
     SET updated_at = CURRENT_TIMESTAMP
   WHERE status IN ('OPEN','IN_PROGRESS')
     AND created_at <= NOW() - INTERVAL fn_setting_num('grievance_escalation_days') DAY;
  SELECT ROW_COUNT() AS grievances_escalated;
END$$

-- ---------------------------------------------------------------------
-- TRIGGERS
-- ---------------------------------------------------------------------

-- Account activation changes are audited.
CREATE TRIGGER trg_user_audit AFTER UPDATE ON app_user
FOR EACH ROW
BEGIN
  IF OLD.is_active <> NEW.is_active THEN
    INSERT INTO user_audit_log (user_id, action, old_value, new_value, changed_by)
    VALUES (NEW.user_id, IF(NEW.is_active = 1, 'REACTIVATED', 'DEACTIVATED'),
            OLD.is_active, NEW.is_active, COALESCE(@app_user, CURRENT_USER()));
  END IF;
END$$

-- Role grants / revocations are audited (companion triggers of trg_user_audit).
CREATE TRIGGER trg_user_role_audit_ins AFTER INSERT ON user_role
FOR EACH ROW
BEGIN
  INSERT INTO user_audit_log (user_id, action, old_value, new_value, changed_by)
  VALUES (NEW.user_id, 'ROLE_ASSIGNED', NULL,
          (SELECT role_name FROM role WHERE role_id = NEW.role_id), COALESCE(@app_user, CURRENT_USER()));
END$$

CREATE TRIGGER trg_user_role_audit_del AFTER DELETE ON user_role
FOR EACH ROW
BEGIN
  INSERT INTO user_audit_log (user_id, action, old_value, new_value, changed_by)
  VALUES (OLD.user_id, 'ROLE_REVOKED',
          (SELECT role_name FROM role WHERE role_id = OLD.role_id), NULL, COALESCE(@app_user, CURRENT_USER()));
END$$

-- A grievance that is still OPEN / IN_PROGRESS after the escalation window becomes ESCALATED
-- the next time it is touched (sp_escalate_overdue_grievances and ev_escalate_grievances touch it daily).
CREATE TRIGGER trg_grievance_escalation BEFORE UPDATE ON grievance
FOR EACH ROW
BEGIN
  IF OLD.status IN ('OPEN','IN_PROGRESS') AND NEW.status IN ('OPEN','IN_PROGRESS')
     AND NEW.created_at <= NOW() - INTERVAL fn_setting_num('grievance_escalation_days') DAY THEN
    SET NEW.status = 'ESCALATED';
    SET NEW.escalated_at = NOW();
  END IF;
END$$

DELIMITER ;

-- Daily run (needs: SET GLOBAL event_scheduler = ON). The procedure can also be CALLed by hand / by the backend.
CREATE EVENT ev_escalate_grievances
  ON SCHEDULE EVERY 1 DAY STARTS (CURRENT_DATE + INTERVAL 1 DAY + INTERVAL 1 HOUR)
  DO CALL sp_escalate_overdue_grievances();
