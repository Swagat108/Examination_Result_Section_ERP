-- =====================================================================
-- 06_placement.sql   |  G7 - Placement & Career Management
-- company, placement_drive, drive_eligible_branch, drive_application,
-- interview_round, round_result, offer.
-- Depends on: 00_admin, 02_students (student), 04_finance (fn_student_fee_due),
--             05_exams (fn_calculate_cgpa, result, grade_scale)
-- Provides:   vw_placement_statistics -> G1 dashboard
-- Resumes / skill profiles live in MongoDB (see db/mongo/).
-- =====================================================================
SET NAMES utf8mb4;

CREATE TABLE company (
  company_id   INT UNSIGNED NOT NULL AUTO_INCREMENT,
  company_name VARCHAR(120) NOT NULL,
  industry     VARCHAR(60)  NULL,
  city         VARCHAR(60)  NULL,
  website      VARCHAR(150) NULL,
  hr_name      VARCHAR(100) NULL,
  hr_email     VARCHAR(120) NULL,
  is_active    TINYINT(1)   NOT NULL DEFAULT 1,
  created_at   TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at   TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT pk_company PRIMARY KEY (company_id),
  CONSTRAINT uq_company_name UNIQUE (company_name),
  CONSTRAINT ck_company_hr_email CHECK (hr_email IS NULL OR hr_email REGEXP '^[^@ ]+@[^@ ]+$')
) ENGINE=InnoDB COMMENT='G7: recruiters';

CREATE TABLE placement_drive (
  drive_id              VARCHAR(12)  NOT NULL COMMENT 'DRV-2026-014',
  company_id            INT UNSIGNED NOT NULL,
  academic_year_id      INT UNSIGNED NOT NULL,
  job_role              VARCHAR(100) NOT NULL,
  job_type              ENUM('FULL_TIME','INTERNSHIP','INTERNSHIP_PPO') NOT NULL DEFAULT 'FULL_TIME',
  package_lpa           DECIMAL(5,2) NOT NULL COMMENT 'lakh rupees per annum',
  min_cgpa              DECIMAL(4,2) NOT NULL DEFAULT 0.00,
  max_backlogs          TINYINT UNSIGNED NOT NULL DEFAULT 0,
  drive_date            DATE         NOT NULL,
  registration_deadline DATE         NULL,
  location              VARCHAR(80)  NULL,
  status                ENUM('UPCOMING','OPEN','CLOSED','COMPLETED') NOT NULL DEFAULT 'UPCOMING',
  created_at            TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at            TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT pk_placement_drive PRIMARY KEY (drive_id),
  CONSTRAINT fk_drive_company FOREIGN KEY (company_id)       REFERENCES company (company_id),
  CONSTRAINT fk_drive_ay      FOREIGN KEY (academic_year_id) REFERENCES academic_year (academic_year_id),
  CONSTRAINT ck_drive_id       CHECK (drive_id REGEXP '^DRV-[0-9]{4}-[0-9]{3}$'),
  CONSTRAINT ck_drive_package  CHECK (package_lpa > 0),
  CONSTRAINT ck_drive_cgpa     CHECK (min_cgpa BETWEEN 0 AND 10),
  CONSTRAINT ck_drive_deadline CHECK (registration_deadline IS NULL OR registration_deadline <= drive_date),
  KEY ix_drive_status (status, drive_date)
) ENGINE=InnoDB COMMENT='G7: a company visit with its eligibility rules';

CREATE TABLE drive_eligible_branch (
  drive_id   VARCHAR(12) NOT NULL,
  dept_code  CHAR(3)     NOT NULL,
  created_at TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT pk_drive_eligible_branch PRIMARY KEY (drive_id, dept_code),
  CONSTRAINT fk_dvbranch_drive FOREIGN KEY (drive_id)  REFERENCES placement_drive (drive_id) ON DELETE CASCADE,
  CONSTRAINT fk_dvbranch_dept  FOREIGN KEY (dept_code) REFERENCES department (dept_code)
) ENGINE=InnoDB COMMENT='G7: branches that may apply to a drive';

CREATE TABLE drive_application (
  application_id INT UNSIGNED NOT NULL AUTO_INCREMENT,
  drive_id       VARCHAR(12)  NOT NULL,
  student_id     CHAR(11)     NOT NULL,
  applied_on     DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  status         ENUM('APPLIED','IN_PROGRESS','REJECTED','SELECTED','WITHDRAWN') NOT NULL DEFAULT 'APPLIED',
  current_round  TINYINT UNSIGNED NOT NULL DEFAULT 0,
  created_at     TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at     TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT pk_drive_application PRIMARY KEY (application_id),
  CONSTRAINT uq_drive_application UNIQUE (student_id, drive_id),
  CONSTRAINT fk_application_drive   FOREIGN KEY (drive_id)   REFERENCES placement_drive (drive_id),
  CONSTRAINT fk_application_student FOREIGN KEY (student_id) REFERENCES student (student_id),
  KEY ix_application_drive (drive_id, status)
) ENGINE=InnoDB COMMENT='G7: a student applying to a drive';

CREATE TABLE interview_round (
  round_id    INT UNSIGNED NOT NULL AUTO_INCREMENT,
  drive_id    VARCHAR(12)  NOT NULL,
  round_no    TINYINT UNSIGNED NOT NULL,
  round_name  VARCHAR(60)  NOT NULL,
  round_type  ENUM('APTITUDE','CODING','GD','TECHNICAL','HR') NOT NULL,
  round_date  DATE         NULL,
  is_final    TINYINT(1)   NOT NULL DEFAULT 0,
  final_flag  TINYINT      GENERATED ALWAYS AS (IF(is_final = 1, 1, NULL)) STORED,
  created_at  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT pk_interview_round PRIMARY KEY (round_id),
  CONSTRAINT uq_interview_round UNIQUE (drive_id, round_no),
  CONSTRAINT uq_interview_round_final UNIQUE (drive_id, final_flag),     -- exactly one final round at most
  CONSTRAINT fk_round_drive FOREIGN KEY (drive_id) REFERENCES placement_drive (drive_id) ON DELETE CASCADE,
  CONSTRAINT ck_round_no CHECK (round_no >= 1)
) ENGINE=InnoDB COMMENT='G7: stages of a drive';

CREATE TABLE round_result (
  round_result_id INT UNSIGNED NOT NULL AUTO_INCREMENT,
  application_id  INT UNSIGNED NOT NULL,
  round_id        INT UNSIGNED NOT NULL,
  status          ENUM('CLEARED','REJECTED','ABSENT') NOT NULL,
  score           DECIMAL(5,2) NULL,
  remarks         VARCHAR(200) NULL,
  evaluated_on    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  created_at      TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at      TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT pk_round_result PRIMARY KEY (round_result_id),
  CONSTRAINT uq_round_result UNIQUE (application_id, round_id),
  CONSTRAINT fk_rresult_application FOREIGN KEY (application_id) REFERENCES drive_application (application_id),
  CONSTRAINT fk_rresult_round       FOREIGN KEY (round_id)       REFERENCES interview_round (round_id),
  CONSTRAINT ck_rresult_score CHECK (score IS NULL OR score BETWEEN 0 AND 100)
) ENGINE=InnoDB COMMENT='G7: outcome of one student in one round';

CREATE TABLE offer (
  offer_id       INT UNSIGNED NOT NULL AUTO_INCREMENT,
  application_id INT UNSIGNED NOT NULL,
  package_lpa    DECIMAL(5,2) NOT NULL,
  offer_date     DATE         NOT NULL DEFAULT (CURRENT_DATE),
  joining_date   DATE         NULL,
  status         ENUM('OFFERED','ACCEPTED','DECLINED','EXPIRED') NOT NULL DEFAULT 'OFFERED',
  responded_on   DATETIME     NULL,
  created_at     TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at     TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT pk_offer PRIMARY KEY (offer_id),
  CONSTRAINT uq_offer_application UNIQUE (application_id),
  CONSTRAINT fk_offer_application FOREIGN KEY (application_id) REFERENCES drive_application (application_id),
  CONSTRAINT ck_offer_package CHECK (package_lpa > 0),
  CONSTRAINT ck_offer_joining CHECK (joining_date IS NULL OR joining_date >= offer_date)
) ENGINE=InnoDB COMMENT='G7: offers made after the final round';

-- ---------------------------------------------------------------------
-- SQL OBJECTS
-- ---------------------------------------------------------------------
DELIMITER $$

-- 'ELIGIBLE' or 'NOT ELIGIBLE: <first reason>'. Rules: active student, branch allowed, CGPA >= drive minimum
-- (G2), backlogs <= drive maximum, no overdue fees (G5). Backlog = a course whose best attempt is a fail grade.
CREATE FUNCTION fn_check_placement_eligibility(p_student_id CHAR(11), p_drive_id VARCHAR(12))
  RETURNS VARCHAR(120)
  READS SQL DATA
BEGIN
  DECLARE v_status VARCHAR(10); DECLARE v_dept CHAR(3);
  DECLARE v_min_cgpa DECIMAL(4,2); DECLARE v_max_backlogs TINYINT UNSIGNED;
  DECLARE v_cgpa DECIMAL(4,2); DECLARE v_backlogs INT; DECLARE v_due DECIMAL(10,2);

  SELECT s.status, p.dept_code INTO v_status, v_dept
    FROM student s JOIN program p ON p.program_id = s.program_id WHERE s.student_id = p_student_id;
  IF v_status IS NULL THEN RETURN 'NOT ELIGIBLE: unknown student'; END IF;
  IF v_status <> 'ACTIVE' THEN RETURN 'NOT ELIGIBLE: student is not active'; END IF;

  SELECT min_cgpa, max_backlogs INTO v_min_cgpa, v_max_backlogs FROM placement_drive WHERE drive_id = p_drive_id;
  IF v_min_cgpa IS NULL THEN RETURN 'NOT ELIGIBLE: unknown drive'; END IF;

  IF NOT EXISTS (SELECT 1 FROM drive_eligible_branch WHERE drive_id = p_drive_id AND dept_code = v_dept) THEN
    RETURN 'NOT ELIGIBLE: branch not allowed for this drive';
  END IF;

  SET v_cgpa = fn_calculate_cgpa(p_student_id);
  IF v_cgpa IS NULL THEN RETURN 'NOT ELIGIBLE: no published results yet'; END IF;
  IF v_cgpa < v_min_cgpa THEN
    RETURN CONCAT('NOT ELIGIBLE: CGPA ', v_cgpa, ' is below the required ', v_min_cgpa);
  END IF;

  SELECT COUNT(*) INTO v_backlogs
    FROM (SELECT c.course_code
            FROM result r
            JOIN course_offering o ON o.offering_id = r.offering_id
            JOIN course c          ON c.course_code = o.course_code
            JOIN grade_scale g     ON g.grade = r.grade
           WHERE r.student_id = p_student_id
           GROUP BY c.course_code
          HAVING MAX(g.is_pass) = 0) b;
  IF v_backlogs > v_max_backlogs THEN
    RETURN CONCAT('NOT ELIGIBLE: ', v_backlogs, ' backlog(s), drive allows ', v_max_backlogs);
  END IF;

  SET v_due = fn_student_fee_due(p_student_id, NULL, 1);
  IF v_due > 0 THEN
    RETURN CONCAT('NOT ELIGIBLE: overdue fees of ', v_due);
  END IF;
  RETURN 'ELIGIBLE';
END$$

-- Registers a student for a drive only if the drive is open and the student is eligible.
CREATE PROCEDURE sp_register_for_drive(
  IN  p_student_id     CHAR(11),
  IN  p_drive_id       VARCHAR(12),
  OUT p_application_id INT UNSIGNED)
BEGIN
  DECLARE v_status VARCHAR(10); DECLARE v_deadline DATE; DECLARE v_check VARCHAR(120);
  DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; RESIGNAL; END;

  SELECT status, registration_deadline INTO v_status, v_deadline FROM placement_drive WHERE drive_id = p_drive_id;
  IF v_status IS NULL THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Unknown drive_id';
  END IF;
  IF v_status <> 'OPEN' OR (v_deadline IS NOT NULL AND v_deadline < CURDATE()) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Registration for this drive is closed';
  END IF;

  SET v_check = fn_check_placement_eligibility(p_student_id, p_drive_id);
  IF v_check <> 'ELIGIBLE' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_check;
  END IF;

  START TRANSACTION;
    INSERT INTO drive_application (drive_id, student_id) VALUES (p_drive_id, p_student_id);
    SET p_application_id = LAST_INSERT_ID();
  COMMIT;
END$$

-- Once a student has ACCEPTED an offer at or above the dream package (app_setting dream_package_lpa),
-- no further drive applications are allowed.
CREATE TRIGGER trg_one_offer_policy BEFORE INSERT ON drive_application
FOR EACH ROW
BEGIN
  IF EXISTS (SELECT 1
               FROM offer o JOIN drive_application a ON a.application_id = o.application_id
              WHERE a.student_id = NEW.student_id AND o.status = 'ACCEPTED'
                AND o.package_lpa >= fn_setting_num('dream_package_lpa')) THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'One-offer policy: student already accepted an offer above the dream package';
  END IF;
END$$

-- Records the result of the next round: CLEARED moves the student on (the final round creates the offer),
-- REJECTED / ABSENT ends the application. Rounds must be recorded in order.
CREATE PROCEDURE sp_record_round_result(
  IN p_application_id INT UNSIGNED,
  IN p_round_no       TINYINT UNSIGNED,
  IN p_status         VARCHAR(10),
  IN p_score          DECIMAL(5,2))
BEGIN
  DECLARE v_drive VARCHAR(12); DECLARE v_app_status VARCHAR(12); DECLARE v_current TINYINT UNSIGNED;
  DECLARE v_round_id INT UNSIGNED; DECLARE v_final TINYINT(1); DECLARE v_pkg DECIMAL(5,2);
  DECLARE v_offer_id INT UNSIGNED DEFAULT NULL;
  DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; RESIGNAL; END;

  START TRANSACTION;
    SELECT drive_id, status, current_round INTO v_drive, v_app_status, v_current
      FROM drive_application WHERE application_id = p_application_id FOR UPDATE;
    IF v_drive IS NULL THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Unknown application_id';
    END IF;
    IF v_app_status NOT IN ('APPLIED','IN_PROGRESS') THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Application is no longer active';
    END IF;
    IF p_round_no <> v_current + 1 THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Rounds must be recorded in order';
    END IF;
    SELECT round_id, is_final INTO v_round_id, v_final
      FROM interview_round WHERE drive_id = v_drive AND round_no = p_round_no;
    IF v_round_id IS NULL THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'This drive has no such round';
    END IF;

    INSERT INTO round_result (application_id, round_id, status, score)
    VALUES (p_application_id, v_round_id, p_status, p_score);

    IF p_status = 'CLEARED' AND v_final = 1 THEN
      UPDATE drive_application SET status = 'SELECTED', current_round = p_round_no
       WHERE application_id = p_application_id;
      SELECT package_lpa INTO v_pkg FROM placement_drive WHERE drive_id = v_drive;
      INSERT INTO offer (application_id, package_lpa) VALUES (p_application_id, v_pkg);
      SET v_offer_id = LAST_INSERT_ID();
    ELSEIF p_status = 'CLEARED' THEN
      UPDATE drive_application SET status = 'IN_PROGRESS', current_round = p_round_no
       WHERE application_id = p_application_id;
    ELSE
      UPDATE drive_application SET status = 'REJECTED', current_round = p_round_no
       WHERE application_id = p_application_id;
    END IF;
  COMMIT;

  SELECT status AS application_status, current_round, v_offer_id AS offer_id
    FROM drive_application WHERE application_id = p_application_id;
END$$

-- Student accepts / declines an offer. Accepting a dream-package offer withdraws their other open applications.
CREATE PROCEDURE sp_respond_to_offer(IN p_offer_id INT UNSIGNED, IN p_accept TINYINT)
BEGIN
  DECLARE v_status VARCHAR(10); DECLARE v_pkg DECIMAL(5,2); DECLARE v_student CHAR(11);
  DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; RESIGNAL; END;

  START TRANSACTION;
    SELECT o.status, o.package_lpa, a.student_id INTO v_status, v_pkg, v_student
      FROM offer o JOIN drive_application a ON a.application_id = o.application_id
     WHERE o.offer_id = p_offer_id FOR UPDATE;
    IF v_status IS NULL THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Unknown offer_id';
    END IF;
    IF v_status <> 'OFFERED' THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Offer has already been answered or has expired';
    END IF;

    UPDATE offer SET status = IF(p_accept = 1, 'ACCEPTED', 'DECLINED'), responded_on = NOW()
     WHERE offer_id = p_offer_id;
    IF p_accept = 1 AND v_pkg >= fn_setting_num('dream_package_lpa') THEN
      UPDATE drive_application SET status = 'WITHDRAWN'
       WHERE student_id = v_student AND status IN ('APPLIED','IN_PROGRESS');
    END IF;
  COMMIT;
END$$

DELIMITER ;

-- Placement statistics per academic department. Cohort = active students registered in the current
-- semester in semester 5 or above; "placed" = at least one ACCEPTED offer.
CREATE VIEW vw_placement_statistics AS
SELECT d.dept_code,
       d.dept_name,
       IFNULL(c.cohort, 0)                                   AS eligible_students,
       IFNULL(p.placed, 0)                                   AS placed_students,
       IFNULL(ROUND(100 * p.placed / NULLIF(c.cohort, 0), 2), 0) AS placed_pct,
       p.highest_package_lpa,
       p.average_package_lpa,
       IFNULL(p.offers_accepted, 0)                          AS offers_accepted
  FROM department d
  LEFT JOIN (SELECT pr.dept_code, COUNT(*) AS cohort
               FROM semester_registration sr
               JOIN student s  ON s.student_id = sr.student_id AND s.status = 'ACTIVE'
               JOIN program pr ON pr.program_id = s.program_id
              WHERE sr.semester_id = fn_current_semester() AND sr.sem_no >= 5
              GROUP BY pr.dept_code) c ON c.dept_code = d.dept_code
  LEFT JOIN (SELECT pr.dept_code,
                    COUNT(DISTINCT a.student_id)      AS placed,
                    MAX(o.package_lpa)                AS highest_package_lpa,
                    ROUND(AVG(o.package_lpa), 2)      AS average_package_lpa,
                    COUNT(*)                          AS offers_accepted
               FROM offer o
               JOIN drive_application a ON a.application_id = o.application_id
               JOIN student s  ON s.student_id = a.student_id
               JOIN program pr ON pr.program_id = s.program_id
              WHERE o.status = 'ACCEPTED'
              GROUP BY pr.dept_code) p ON p.dept_code = d.dept_code
 WHERE d.dept_type = 'ACADEMIC';
