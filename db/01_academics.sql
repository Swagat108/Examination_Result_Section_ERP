-- =====================================================================
-- 01_academics.sql   |  G3 - Academic Management
-- employee (faculty/staff), designation, course, prerequisites,
-- curriculum, classroom, course_offering, timetable_slot.
-- Depends on: 00_admin.sql (department, program, semester, division, batch)
-- Provides:   employee -> G1/G4/G5, course_offering -> G2/G4/G6
-- =====================================================================
SET NAMES utf8mb4;

CREATE TABLE designation (
  designation_id   TINYINT UNSIGNED NOT NULL AUTO_INCREMENT,
  designation_name VARCHAR(60)      NOT NULL,
  rank_order       TINYINT UNSIGNED NOT NULL COMMENT '1 = most senior',
  created_at       TIMESTAMP        NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at       TIMESTAMP        NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT pk_designation PRIMARY KEY (designation_id),
  CONSTRAINT uq_designation_name UNIQUE (designation_name)
) ENGINE=InnoDB COMMENT='G3: Professor, Associate Professor, ...';

CREATE TABLE employee (
  employee_id     CHAR(7)      NOT NULL COMMENT 'EMP0107',
  full_name       VARCHAR(120) NOT NULL,
  email           VARCHAR(120) NOT NULL,
  phone           VARCHAR(15)  NULL,
  gender          ENUM('M','F','O') NULL,
  date_of_birth   DATE         NULL,
  dept_code       CHAR(3)      NOT NULL,
  designation_id  TINYINT UNSIGNED NOT NULL,
  employee_type   ENUM('TEACHING','NON_TEACHING') NOT NULL DEFAULT 'TEACHING',
  qualification   VARCHAR(100) NULL,
  joining_date    DATE         NOT NULL,
  status          ENUM('ACTIVE','ON_LEAVE','RESIGNED','RETIRED') NOT NULL DEFAULT 'ACTIVE',
  created_at      TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at      TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT pk_employee PRIMARY KEY (employee_id),
  CONSTRAINT uq_employee_email UNIQUE (email),
  CONSTRAINT fk_employee_dept        FOREIGN KEY (dept_code)       REFERENCES department (dept_code),
  CONSTRAINT fk_employee_designation FOREIGN KEY (designation_id)  REFERENCES designation (designation_id),
  CONSTRAINT ck_employee_id    CHECK (employee_id REGEXP '^EMP[0-9]{4}$'),
  CONSTRAINT ck_employee_dob   CHECK (date_of_birth IS NULL OR date_of_birth BETWEEN '1940-01-01' AND '2006-12-31'),
  CONSTRAINT ck_employee_email CHECK (email REGEXP '^[^@ ]+@[^@ ]+$'),
  KEY ix_employee_dept (dept_code, status)
) ENGINE=InnoDB COMMENT='G3: faculty and non-teaching staff';

-- The department head is an employee (closes the department <-> employee loop).
ALTER TABLE department
  ADD CONSTRAINT fk_department_hod FOREIGN KEY (hod_employee_id) REFERENCES employee (employee_id);

CREATE TABLE course (
  course_code   VARCHAR(8)       NOT NULL COMMENT 'ETC301',
  course_title  VARCHAR(150)     NOT NULL,
  credits       TINYINT UNSIGNED NOT NULL,
  course_type   ENUM('THEORY','LAB','PROJECT') NOT NULL DEFAULT 'THEORY',
  category      ENUM('CORE','PROGRAM_ELECTIVE','HONORS','MDM','OPEN_ELECTIVE') NOT NULL DEFAULT 'CORE',
  dept_code     CHAR(3)          NOT NULL,
  lecture_hrs   TINYINT UNSIGNED NOT NULL DEFAULT 0,
  tutorial_hrs  TINYINT UNSIGNED NOT NULL DEFAULT 0,
  practical_hrs TINYINT UNSIGNED NOT NULL DEFAULT 0,
  created_at    TIMESTAMP        NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at    TIMESTAMP        NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT pk_course PRIMARY KEY (course_code),
  CONSTRAINT fk_course_dept FOREIGN KEY (dept_code) REFERENCES department (dept_code),
  CONSTRAINT ck_course_code    CHECK (course_code REGEXP '^[A-Z]{3}[0-9]{3}$'),
  CONSTRAINT ck_course_credits CHECK (credits BETWEEN 1 AND 6),
  CONSTRAINT ck_course_hours   CHECK (lecture_hrs + tutorial_hrs + practical_hrs > 0)
) ENGINE=InnoDB COMMENT='G3: course catalogue';

CREATE TABLE course_prerequisite (
  course_code        VARCHAR(8) NOT NULL,
  prereq_course_code VARCHAR(8) NOT NULL,
  created_at         TIMESTAMP  NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at         TIMESTAMP  NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT pk_course_prerequisite PRIMARY KEY (course_code, prereq_course_code),
  CONSTRAINT fk_prereq_course FOREIGN KEY (course_code)        REFERENCES course (course_code),
  CONSTRAINT fk_prereq_prereq FOREIGN KEY (prereq_course_code) REFERENCES course (course_code),  -- self-referencing
  CONSTRAINT ck_prereq_not_self CHECK (course_code <> prereq_course_code)
) ENGINE=InnoDB COMMENT='G3: course must be passed before another (self-referencing FK pair)';

CREATE TABLE curriculum (
  curriculum_id  INT UNSIGNED     NOT NULL AUTO_INCREMENT,
  program_id     INT UNSIGNED     NOT NULL,
  sem_no         TINYINT UNSIGNED NOT NULL,
  course_code    VARCHAR(8)       NOT NULL,
  elective_group VARCHAR(10)      NULL COMMENT 'PE-1 / HONORS / MDM for choice courses, NULL for core',
  created_at     TIMESTAMP        NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at     TIMESTAMP        NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT pk_curriculum PRIMARY KEY (curriculum_id),
  CONSTRAINT uq_curriculum UNIQUE (program_id, sem_no, course_code),
  CONSTRAINT fk_curriculum_program FOREIGN KEY (program_id)  REFERENCES program (program_id),
  CONSTRAINT fk_curriculum_course  FOREIGN KEY (course_code) REFERENCES course (course_code),
  CONSTRAINT ck_curriculum_sem CHECK (sem_no BETWEEN 1 AND 8)
) ENGINE=InnoDB COMMENT='G3: which courses a program studies in which semester number';

CREATE TABLE classroom (
  classroom_id   INT UNSIGNED  NOT NULL AUTO_INCREMENT,
  classroom_code VARCHAR(10)   NOT NULL COMMENT 'LH-301, LAB-DSP',
  building       VARCHAR(40)   NOT NULL,
  capacity       SMALLINT UNSIGNED NOT NULL,
  room_type      ENUM('LECTURE','LAB','SEMINAR') NOT NULL DEFAULT 'LECTURE',
  created_at     TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at     TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT pk_classroom PRIMARY KEY (classroom_id),
  CONSTRAINT uq_classroom_code UNIQUE (classroom_code),
  CONSTRAINT ck_classroom_capacity CHECK (capacity > 0)
) ENGINE=InnoDB COMMENT='G3: lecture halls and labs';

CREATE TABLE course_offering (
  offering_id  INT UNSIGNED NOT NULL AUTO_INCREMENT,
  course_code  VARCHAR(8)   NOT NULL,
  semester_id  INT UNSIGNED NOT NULL,
  division_id  INT UNSIGNED NULL COMMENT 'NULL = shared across divisions (electives / honors / MDM)',
  employee_id  CHAR(7)      NULL COMMENT 'faculty in charge; assigned after generation',
  max_seats    SMALLINT UNSIGNED NOT NULL DEFAULT 90,
  division_key INT UNSIGNED GENERATED ALWAYS AS (IFNULL(division_id, 0)) STORED,
  created_at   TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at   TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT pk_course_offering PRIMARY KEY (offering_id),
  CONSTRAINT uq_course_offering UNIQUE (course_code, semester_id, division_key),
  CONSTRAINT fk_offering_course   FOREIGN KEY (course_code) REFERENCES course (course_code),
  CONSTRAINT fk_offering_semester FOREIGN KEY (semester_id) REFERENCES semester (semester_id),
  CONSTRAINT fk_offering_division FOREIGN KEY (division_id) REFERENCES division (division_id),
  CONSTRAINT fk_offering_employee FOREIGN KEY (employee_id) REFERENCES employee (employee_id),
  CONSTRAINT ck_offering_seats CHECK (max_seats > 0),
  KEY ix_offering_semester (semester_id)
) ENGINE=InnoDB COMMENT='G3: a course taught in a semester (per division for core courses)';

CREATE TABLE timetable_slot (
  slot_id      INT UNSIGNED NOT NULL AUTO_INCREMENT,
  offering_id  INT UNSIGNED NOT NULL,
  classroom_id INT UNSIGNED NOT NULL,
  employee_id  CHAR(7)      NOT NULL,
  batch_id     INT UNSIGNED NULL COMMENT 'set for batch-wise practicals',
  day_of_week  ENUM('MON','TUE','WED','THU','FRI','SAT') NOT NULL,
  start_time   TIME         NOT NULL,
  end_time     TIME         NOT NULL,
  slot_type    ENUM('LECTURE','LAB','TUTORIAL') NOT NULL DEFAULT 'LECTURE',
  created_at   TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at   TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT pk_timetable_slot PRIMARY KEY (slot_id),
  CONSTRAINT fk_slot_offering  FOREIGN KEY (offering_id)  REFERENCES course_offering (offering_id) ON DELETE CASCADE,
  CONSTRAINT fk_slot_classroom FOREIGN KEY (classroom_id) REFERENCES classroom (classroom_id),
  CONSTRAINT fk_slot_employee  FOREIGN KEY (employee_id)  REFERENCES employee (employee_id),
  CONSTRAINT fk_slot_batch     FOREIGN KEY (batch_id)     REFERENCES batch (batch_id),
  CONSTRAINT ck_slot_times CHECK (end_time > start_time),
  KEY ix_slot_faculty   (employee_id,  day_of_week, start_time),
  KEY ix_slot_classroom (classroom_id, day_of_week, start_time)
) ENGINE=InnoDB COMMENT='G3: weekly timetable; trg_timetable_clash prevents double booking';

-- ---------------------------------------------------------------------
-- SQL OBJECTS
-- ---------------------------------------------------------------------
DELIMITER $$

-- Creates offerings for the curriculum of a term.
--   p_sem_no NULL  -> every curriculum semester of the right parity (odd/even)
--   p_sem_no = n   -> only that semester number
-- CORE courses get one offering per division of that program/year (or one shared offering if the
-- program has no divisions yet); electives / honors / MDM get one shared offering. Re-runnable.
-- (Extra p_sem_no vs. the plan: needed so a past even term can be generated for Sem 4 only.)
CREATE PROCEDURE sp_generate_course_offerings(IN p_semester_id INT UNSIGNED, IN p_sem_no TINYINT UNSIGNED)
BEGIN
  DECLARE v_term ENUM('ODD','EVEN');
  DECLARE v_ay   INT UNSIGNED;
  DECLARE v_parity TINYINT;
  DECLARE v_core INT DEFAULT 0;
  DECLARE v_shared INT DEFAULT 0;
  DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; RESIGNAL; END;

  SELECT term, academic_year_id INTO v_term, v_ay FROM semester WHERE semester_id = p_semester_id;
  IF v_term IS NULL THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Unknown semester_id';
  END IF;
  SET v_parity = IF(v_term = 'ODD', 1, 0);

  START TRANSACTION;

  -- core courses, one offering per division
  INSERT INTO course_offering (course_code, semester_id, division_id, max_seats)
  SELECT cu.course_code, p_semester_id, d.division_id, 90
    FROM curriculum cu
    JOIN course   c ON c.course_code = cu.course_code AND c.category = 'CORE'
    JOIN division d ON d.program_id = cu.program_id AND d.academic_year_id = v_ay
                   AND d.year_of_study = CEIL(cu.sem_no / 2)
   WHERE MOD(cu.sem_no, 2) = v_parity AND (p_sem_no IS NULL OR cu.sem_no = p_sem_no)
     AND NOT EXISTS (SELECT 1 FROM course_offering o
                      WHERE o.course_code = cu.course_code AND o.semester_id = p_semester_id
                        AND o.division_id = d.division_id);
  SET v_core = ROW_COUNT();

  -- core courses of programs without divisions in that year, and all choice courses: one shared offering
  INSERT INTO course_offering (course_code, semester_id, division_id, max_seats)
  SELECT x.course_code, p_semester_id, NULL, MAX(x.seats)
    FROM (SELECT cu.course_code,
                 CASE c.category WHEN 'CORE' THEN 90 WHEN 'PROGRAM_ELECTIVE' THEN 200
                                 WHEN 'HONORS' THEN 60 ELSE 80 END AS seats
            FROM curriculum cu
            JOIN course c ON c.course_code = cu.course_code
           WHERE MOD(cu.sem_no, 2) = v_parity AND (p_sem_no IS NULL OR cu.sem_no = p_sem_no)
             AND (c.category <> 'CORE'
                  OR NOT EXISTS (SELECT 1 FROM division d
                                  WHERE d.program_id = cu.program_id AND d.academic_year_id = v_ay
                                    AND d.year_of_study = CEIL(cu.sem_no / 2)))) x
   WHERE NOT EXISTS (SELECT 1 FROM course_offering o
                      WHERE o.course_code = x.course_code AND o.semester_id = p_semester_id
                        AND o.division_id IS NULL)
   GROUP BY x.course_code;
  SET v_shared = ROW_COUNT();

  COMMIT;
  SELECT v_core AS core_offerings_created, v_shared AS shared_offerings_created;
END$$

-- Raises an error if the proposed slot double-books the faculty member or the room in the same term.
CREATE PROCEDURE sp_assert_no_timetable_clash(
  IN p_slot_id INT UNSIGNED, IN p_offering_id INT UNSIGNED, IN p_employee_id CHAR(7),
  IN p_classroom_id INT UNSIGNED, IN p_day VARCHAR(3), IN p_start TIME, IN p_end TIME)
BEGIN
  DECLARE v_sem INT UNSIGNED;
  SELECT semester_id INTO v_sem FROM course_offering WHERE offering_id = p_offering_id;

  IF EXISTS (SELECT 1 FROM timetable_slot t JOIN course_offering o ON o.offering_id = t.offering_id
              WHERE o.semester_id = v_sem AND t.day_of_week = p_day AND t.slot_id <> IFNULL(p_slot_id, 0)
                AND t.employee_id = p_employee_id AND t.start_time < p_end AND t.end_time > p_start) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Timetable clash: faculty already teaching at that time';
  END IF;
  IF EXISTS (SELECT 1 FROM timetable_slot t JOIN course_offering o ON o.offering_id = t.offering_id
              WHERE o.semester_id = v_sem AND t.day_of_week = p_day AND t.slot_id <> IFNULL(p_slot_id, 0)
                AND t.classroom_id = p_classroom_id AND t.start_time < p_end AND t.end_time > p_start) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Timetable clash: classroom already booked at that time';
  END IF;
END$$

CREATE TRIGGER trg_timetable_clash BEFORE INSERT ON timetable_slot
FOR EACH ROW
BEGIN
  CALL sp_assert_no_timetable_clash(NULL, NEW.offering_id, NEW.employee_id, NEW.classroom_id,
                                    NEW.day_of_week, NEW.start_time, NEW.end_time);
END$$

CREATE TRIGGER trg_timetable_clash_upd BEFORE UPDATE ON timetable_slot
FOR EACH ROW
BEGIN
  CALL sp_assert_no_timetable_clash(OLD.slot_id, NEW.offering_id, NEW.employee_id, NEW.classroom_id,
                                    NEW.day_of_week, NEW.start_time, NEW.end_time);
END$$

-- Teaching hours per week of a faculty member in the active semester.
CREATE FUNCTION fn_faculty_weekly_load(p_employee_id CHAR(7)) RETURNS DECIMAL(5,2)
  READS SQL DATA
BEGIN
  DECLARE v_hours DECIMAL(5,2);
  SELECT IFNULL(ROUND(SUM(TIME_TO_SEC(TIMEDIFF(t.end_time, t.start_time))) / 3600, 2), 0)
    INTO v_hours
    FROM timetable_slot t
    JOIN course_offering o ON o.offering_id = t.offering_id
   WHERE t.employee_id = p_employee_id AND o.semester_id = fn_current_semester();
  RETURN v_hours;
END$$

DELIMITER ;

-- Weekly timetable: day x slot x course x faculty x room
CREATE VIEW vw_timetable AS
SELECT o.semester_id,
       dv.division_name,
       b.batch_code,
       t.day_of_week,
       t.start_time,
       t.end_time,
       t.slot_type,
       c.course_code,
       c.course_title,
       e.employee_id,
       e.full_name  AS faculty_name,
       r.classroom_code,
       r.building
  FROM timetable_slot t
  JOIN course_offering o ON o.offering_id  = t.offering_id
  JOIN course          c ON c.course_code  = o.course_code
  JOIN employee        e ON e.employee_id  = t.employee_id
  JOIN classroom       r ON r.classroom_id = t.classroom_id
  LEFT JOIN division   dv ON dv.division_id = o.division_id
  LEFT JOIN batch      b  ON b.batch_id     = t.batch_id;
