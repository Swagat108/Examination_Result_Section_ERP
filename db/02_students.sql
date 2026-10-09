-- =====================================================================
-- 02_students.sql   |  G6 - Student Management
-- student, guardian, admission, semester_registration, elective_selection,
-- course_enrollment, hostel, room, room_allocation.
-- Depends on: 00_admin.sql (program, academic_year, semester, division, batch),
--             01_academics.sql (employee, course, course_offering)
-- Provides:   student -> every other module
-- =====================================================================
SET NAMES utf8mb4;

CREATE TABLE student (
  student_id     CHAR(11)     NOT NULL COMMENT 'year + dept + serial, e.g. 2026ETC0042',
  enrollment_no  VARCHAR(12)  NOT NULL COMMENT 'university enrollment no, e.g. F24ET362 / S25ET024',
  full_name      VARCHAR(120) NOT NULL,
  email          VARCHAR(120) NOT NULL,
  phone          VARCHAR(15)  NULL,
  gender         ENUM('M','F','O') NULL,
  date_of_birth  DATE         NULL,
  address        VARCHAR(255) NULL,
  program_id     INT UNSIGNED NOT NULL,
  admission_year YEAR         NOT NULL,
  status         ENUM('ACTIVE','GRADUATED','DROPPED','SUSPENDED') NOT NULL DEFAULT 'ACTIVE',
  created_at     TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at     TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT pk_student PRIMARY KEY (student_id),
  CONSTRAINT uq_student_enrollment UNIQUE (enrollment_no),
  CONSTRAINT uq_student_email      UNIQUE (email),
  CONSTRAINT fk_student_program FOREIGN KEY (program_id) REFERENCES program (program_id),
  CONSTRAINT ck_student_id    CHECK (student_id REGEXP '^[0-9]{4}[A-Z]{3}[0-9]{4}$'),
  CONSTRAINT ck_student_email CHECK (email REGEXP '^[^@ ]+@[^@ ]+$'),
  CONSTRAINT ck_student_dob   CHECK (date_of_birth IS NULL OR date_of_birth BETWEEN '1990-01-01' AND '2012-12-31'),
  KEY ix_student_program (program_id, status)
) ENGINE=InnoDB COMMENT='G6: student master record';

CREATE TABLE guardian (
  guardian_id   INT UNSIGNED NOT NULL AUTO_INCREMENT,
  student_id    CHAR(11)     NOT NULL,
  guardian_name VARCHAR(120) NOT NULL,
  relation      ENUM('FATHER','MOTHER','GUARDIAN','OTHER') NOT NULL,
  phone         VARCHAR(15)  NULL,
  email         VARCHAR(120) NULL,
  occupation    VARCHAR(80)  NULL,
  is_primary    TINYINT(1)   NOT NULL DEFAULT 0,
  primary_flag  TINYINT      GENERATED ALWAYS AS (IF(is_primary = 1, 1, NULL)) STORED,
  created_at    TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at    TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT pk_guardian PRIMARY KEY (guardian_id),
  CONSTRAINT uq_guardian_primary UNIQUE (student_id, primary_flag),       -- one primary guardian per student
  CONSTRAINT fk_guardian_student FOREIGN KEY (student_id) REFERENCES student (student_id) ON DELETE CASCADE,
  KEY ix_guardian_student (student_id)
) ENGINE=InnoDB COMMENT='G6: parents / guardians';

CREATE TABLE admission (
  admission_id     INT UNSIGNED NOT NULL AUTO_INCREMENT,
  student_id       CHAR(11)     NOT NULL,
  program_id       INT UNSIGNED NOT NULL,
  academic_year_id INT UNSIGNED NOT NULL,
  admission_type   ENUM('REGULAR','DIRECT_SECOND_YEAR') NOT NULL DEFAULT 'REGULAR',
  admission_date   DATE         NULL,
  merit_score      DECIMAL(5,2) NULL,
  status           ENUM('PROVISIONAL','CONFIRMED','CANCELLED') NOT NULL DEFAULT 'CONFIRMED',
  created_at       TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at       TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT pk_admission PRIMARY KEY (admission_id),
  CONSTRAINT uq_admission_student UNIQUE (student_id),
  CONSTRAINT fk_admission_student FOREIGN KEY (student_id)       REFERENCES student (student_id),
  CONSTRAINT fk_admission_program FOREIGN KEY (program_id)       REFERENCES program (program_id),
  CONSTRAINT fk_admission_ay      FOREIGN KEY (academic_year_id) REFERENCES academic_year (academic_year_id),
  CONSTRAINT ck_admission_merit   CHECK (merit_score IS NULL OR merit_score BETWEEN 0 AND 100),
  KEY ix_admission_program_year (program_id, academic_year_id)
) ENGINE=InnoDB COMMENT='G6: admission record (one per student)';

-- A student's registration for a term: which semester number, division, batch and roll number.
CREATE TABLE semester_registration (
  registration_id INT UNSIGNED     NOT NULL AUTO_INCREMENT,
  student_id      CHAR(11)         NOT NULL,
  semester_id     INT UNSIGNED     NOT NULL,
  sem_no          TINYINT UNSIGNED NOT NULL,
  division_id     INT UNSIGNED     NULL,
  batch_id        INT UNSIGNED     NULL,
  roll_no         VARCHAR(10)      NULL COMMENT 'class roll no for the year, e.g. 32101',
  status          ENUM('REGISTERED','CANCELLED','COMPLETED','DETAINED') NOT NULL DEFAULT 'REGISTERED',
  registered_on   DATE             NULL,
  created_at      TIMESTAMP        NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at      TIMESTAMP        NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT pk_semester_registration PRIMARY KEY (registration_id),
  CONSTRAINT uq_semreg_student_sem UNIQUE (student_id, semester_id),
  CONSTRAINT uq_semreg_roll        UNIQUE (semester_id, roll_no),
  CONSTRAINT fk_semreg_student  FOREIGN KEY (student_id)  REFERENCES student (student_id),
  CONSTRAINT fk_semreg_semester FOREIGN KEY (semester_id) REFERENCES semester (semester_id),
  CONSTRAINT fk_semreg_division FOREIGN KEY (division_id) REFERENCES division (division_id),
  CONSTRAINT fk_semreg_batch    FOREIGN KEY (batch_id)    REFERENCES batch (batch_id),
  CONSTRAINT ck_semreg_sem CHECK (sem_no BETWEEN 1 AND 8),
  KEY ix_semreg_division (semester_id, division_id)
) ENGINE=InnoDB COMMENT='G6: per-term registration (division, batch, roll no)';

-- The elective / honors / MDM course a student picked for a term (PE-1, HONORS, MDM ...).
CREATE TABLE elective_selection (
  selection_id   INT UNSIGNED NOT NULL AUTO_INCREMENT,
  student_id     CHAR(11)     NOT NULL,
  semester_id    INT UNSIGNED NOT NULL,
  elective_group VARCHAR(10)  NOT NULL COMMENT 'PE-1, HONORS, MDM',
  course_code    VARCHAR(8)   NOT NULL,
  created_at     TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at     TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT pk_elective_selection PRIMARY KEY (selection_id),
  CONSTRAINT uq_elective_selection UNIQUE (student_id, semester_id, elective_group),
  CONSTRAINT fk_elective_student  FOREIGN KEY (student_id)  REFERENCES student (student_id),
  CONSTRAINT fk_elective_semester FOREIGN KEY (semester_id) REFERENCES semester (semester_id),
  CONSTRAINT fk_elective_course   FOREIGN KEY (course_code) REFERENCES course (course_code),
  KEY ix_elective_course (semester_id, course_code)
) ENGINE=InnoDB COMMENT='G6: elective choices (source: Final Electives & Honors roll call)';

CREATE TABLE course_enrollment (
  enrollment_id INT UNSIGNED NOT NULL AUTO_INCREMENT,
  student_id    CHAR(11)     NOT NULL,
  offering_id   INT UNSIGNED NOT NULL,
  enrolled_on   DATE         NOT NULL DEFAULT (CURRENT_DATE),
  status        ENUM('ENROLLED','DROPPED','COMPLETED') NOT NULL DEFAULT 'ENROLLED',
  created_at    TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at    TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT pk_course_enrollment PRIMARY KEY (enrollment_id),
  CONSTRAINT uq_course_enrollment UNIQUE (student_id, offering_id),
  CONSTRAINT fk_enrollment_student  FOREIGN KEY (student_id)  REFERENCES student (student_id),
  CONSTRAINT fk_enrollment_offering FOREIGN KEY (offering_id) REFERENCES course_offering (offering_id),
  KEY ix_enrollment_offering (offering_id, status)
) ENGINE=InnoDB COMMENT='G6: student <-> course offering';

CREATE TABLE hostel (
  hostel_id          INT UNSIGNED NOT NULL AUTO_INCREMENT,
  hostel_code        VARCHAR(4)   NOT NULL COMMENT 'BH1, BH2, GH1',
  hostel_name        VARCHAR(80)  NOT NULL,
  hostel_type        ENUM('BOYS','GIRLS') NOT NULL,
  warden_employee_id CHAR(7)      NULL,
  created_at         TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at         TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT pk_hostel PRIMARY KEY (hostel_id),
  CONSTRAINT uq_hostel_code UNIQUE (hostel_code),
  CONSTRAINT fk_hostel_warden FOREIGN KEY (warden_employee_id) REFERENCES employee (employee_id)
) ENGINE=InnoDB COMMENT='G6: hostel blocks';

CREATE TABLE room (
  room_code       VARCHAR(8)       NOT NULL COMMENT 'BH1-204',
  hostel_id       INT UNSIGNED     NOT NULL,
  floor_no        TINYINT UNSIGNED NOT NULL,
  capacity        TINYINT UNSIGNED NOT NULL,
  available_beds  TINYINT UNSIGNED NOT NULL,
  created_at      TIMESTAMP        NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at      TIMESTAMP        NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT pk_room PRIMARY KEY (room_code),
  CONSTRAINT fk_room_hostel FOREIGN KEY (hostel_id) REFERENCES hostel (hostel_id),
  CONSTRAINT ck_room_code     CHECK (room_code REGEXP '^[A-Z]{2}[0-9]-[0-9]{3}$'),
  CONSTRAINT ck_room_capacity CHECK (capacity BETWEEN 1 AND 6),
  CONSTRAINT ck_room_beds     CHECK (available_beds >= 0 AND available_beds <= capacity)
) ENGINE=InnoDB COMMENT='G6: hostel rooms with live bed count';

CREATE TABLE room_allocation (
  allocation_id    INT UNSIGNED NOT NULL AUTO_INCREMENT,
  room_code        VARCHAR(8)   NOT NULL,
  student_id       CHAR(11)     NOT NULL,
  academic_year_id INT UNSIGNED NOT NULL,
  allocated_on     DATE         NOT NULL DEFAULT (CURRENT_DATE),
  vacated_on       DATE         NULL,
  status           ENUM('ACTIVE','VACATED') NOT NULL DEFAULT 'ACTIVE',
  active_student   CHAR(11)     GENERATED ALWAYS AS (IF(status = 'ACTIVE', student_id, NULL)) STORED,
  created_at       TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at       TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT pk_room_allocation PRIMARY KEY (allocation_id),
  CONSTRAINT uq_room_allocation_active UNIQUE (active_student),            -- one live bed per student
  CONSTRAINT fk_alloc_room    FOREIGN KEY (room_code)        REFERENCES room (room_code),
  CONSTRAINT fk_alloc_student FOREIGN KEY (student_id)       REFERENCES student (student_id),
  CONSTRAINT fk_alloc_ay      FOREIGN KEY (academic_year_id) REFERENCES academic_year (academic_year_id),
  CONSTRAINT ck_alloc_dates   CHECK (vacated_on IS NULL OR vacated_on >= allocated_on),
  CONSTRAINT ck_alloc_state   CHECK ((status = 'ACTIVE' AND vacated_on IS NULL) OR (status = 'VACATED' AND vacated_on IS NOT NULL)),
  KEY ix_alloc_room (room_code, status)
) ENGINE=InnoDB COMMENT='G6: who sleeps where; trg_room_allocation_beds keeps room.available_beds right';

-- ---------------------------------------------------------------------
-- SQL OBJECTS
-- ---------------------------------------------------------------------
DELIMITER $$

-- Next student id for a year + department, e.g. fn_generate_student_id(2026,'ETC') -> 2026ETC0001
CREATE FUNCTION fn_generate_student_id(p_year SMALLINT UNSIGNED, p_dept_code CHAR(3)) RETURNS CHAR(11)
  READS SQL DATA
BEGIN
  DECLARE v_next INT;
  SELECT IFNULL(MAX(CAST(SUBSTRING(student_id, 8, 4) AS UNSIGNED)), 0) + 1 INTO v_next
    FROM student
   WHERE student_id LIKE CONCAT(p_year, p_dept_code, '%');
  IF v_next > 9999 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Student serial exhausted for this year and department';
  END IF;
  RETURN CONCAT(p_year, p_dept_code, LPAD(v_next, 4, '0'));
END$$

-- Admits a student: student + primary guardian + admission row in one transaction.
-- A named lock serialises id generation so two admissions never get the same serial.
CREATE PROCEDURE sp_admit_student(
  IN  p_enrollment_no  VARCHAR(12),
  IN  p_full_name      VARCHAR(120),
  IN  p_email          VARCHAR(120),
  IN  p_phone          VARCHAR(15),
  IN  p_gender         VARCHAR(1),
  IN  p_dob            DATE,
  IN  p_program_id     INT UNSIGNED,
  IN  p_admission_year SMALLINT UNSIGNED,
  IN  p_admission_type VARCHAR(20),
  IN  p_guardian_name  VARCHAR(120),
  IN  p_guardian_rel   VARCHAR(10),
  IN  p_guardian_phone VARCHAR(15),
  OUT p_student_id     CHAR(11))
BEGIN
  DECLARE v_dept CHAR(3);
  DECLARE v_ay   INT UNSIGNED;
  DECLARE v_lock INT DEFAULT 0;
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    DO RELEASE_LOCK('erp_student_id');
    RESIGNAL;
  END;

  SELECT dept_code INTO v_dept FROM program WHERE program_id = p_program_id;
  IF v_dept IS NULL THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Unknown program_id';
  END IF;
  SELECT academic_year_id INTO v_ay FROM academic_year WHERE YEAR(start_date) = p_admission_year LIMIT 1;
  IF v_ay IS NULL THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'No academic year starts in the admission year';
  END IF;

  SELECT GET_LOCK('erp_student_id', 10) INTO v_lock;
  IF v_lock <> 1 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Could not obtain the student-id lock, retry';
  END IF;

  START TRANSACTION;
    SET p_student_id = fn_generate_student_id(p_admission_year, v_dept);
    INSERT INTO student (student_id, enrollment_no, full_name, email, phone, gender, date_of_birth,
                         program_id, admission_year)
    VALUES (p_student_id, p_enrollment_no, p_full_name,
            COALESCE(p_email, CONCAT(LOWER(p_enrollment_no), '@students.erp.local')),
            p_phone, p_gender, p_dob, p_program_id, p_admission_year);
    IF p_guardian_name IS NOT NULL THEN
      INSERT INTO guardian (student_id, guardian_name, relation, phone, is_primary)
      VALUES (p_student_id, p_guardian_name, COALESCE(p_guardian_rel, 'GUARDIAN'), p_guardian_phone, 1);
    END IF;
    INSERT INTO admission (student_id, program_id, academic_year_id, admission_type, admission_date)
    VALUES (p_student_id, p_program_id, v_ay, COALESCE(p_admission_type, 'REGULAR'), CURRENT_DATE);
  COMMIT;
  DO RELEASE_LOCK('erp_student_id');
END$$

-- Enrolls every registered student of a program into the offerings of their semester:
--   * CORE courses of their division (curriculum of the program/semester no.)
--   * the elective / honors / MDM courses they picked (elective_selection)
-- All-or-nothing: if any offering would exceed max_seats the whole run is rolled back.
CREATE PROCEDURE sp_bulk_enroll_students(IN p_program_id INT UNSIGNED, IN p_semester_id INT UNSIGNED)
BEGIN
  DECLARE v_core INT DEFAULT 0;
  DECLARE v_elec INT DEFAULT 0;
  DECLARE v_full VARCHAR(8);
  DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; RESIGNAL; END;

  IF NOT EXISTS (SELECT 1 FROM program WHERE program_id = p_program_id) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Unknown program_id';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM semester WHERE semester_id = p_semester_id) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Unknown semester_id';
  END IF;

  START TRANSACTION;

  INSERT INTO course_enrollment (student_id, offering_id)
  SELECT sr.student_id, o.offering_id
    FROM semester_registration sr
    JOIN student s    ON s.student_id = sr.student_id AND s.program_id = p_program_id AND s.status = 'ACTIVE'
    JOIN curriculum cu ON cu.program_id = s.program_id AND cu.sem_no = sr.sem_no
    JOIN course c     ON c.course_code = cu.course_code AND c.category = 'CORE'
    JOIN course_offering o ON o.course_code = cu.course_code AND o.semester_id = sr.semester_id
                          AND (o.division_id = sr.division_id OR o.division_id IS NULL)
   WHERE sr.semester_id = p_semester_id AND sr.status = 'REGISTERED'
     AND NOT EXISTS (SELECT 1 FROM course_enrollment ce
                      WHERE ce.student_id = sr.student_id AND ce.offering_id = o.offering_id);
  SET v_core = ROW_COUNT();

  INSERT INTO course_enrollment (student_id, offering_id)
  SELECT es.student_id, o.offering_id
    FROM elective_selection es
    JOIN semester_registration sr ON sr.student_id = es.student_id AND sr.semester_id = es.semester_id
                                 AND sr.status = 'REGISTERED'
    JOIN student s ON s.student_id = es.student_id AND s.program_id = p_program_id AND s.status = 'ACTIVE'
    JOIN course_offering o ON o.course_code = es.course_code AND o.semester_id = es.semester_id
                          AND o.division_id IS NULL
   WHERE es.semester_id = p_semester_id
     AND NOT EXISTS (SELECT 1 FROM course_enrollment ce
                      WHERE ce.student_id = es.student_id AND ce.offering_id = o.offering_id);
  SET v_elec = ROW_COUNT();

  -- capacity guard
  SELECT o.course_code INTO v_full
    FROM course_offering o
    JOIN course_enrollment ce ON ce.offering_id = o.offering_id AND ce.status = 'ENROLLED'
   WHERE o.semester_id = p_semester_id
   GROUP BY o.offering_id, o.course_code, o.max_seats
  HAVING COUNT(*) > o.max_seats
   LIMIT 1;
  IF v_full IS NOT NULL THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Bulk enrollment rolled back: an offering exceeds max_seats';
  END IF;

  COMMIT;
  SELECT v_core AS core_enrollments_created, v_elec AS elective_enrollments_created;
END$$

-- Hostel beds: allocation takes a bed (blocked at 0) ...
CREATE TRIGGER trg_room_allocation_beds BEFORE INSERT ON room_allocation
FOR EACH ROW
BEGIN
  IF NEW.status = 'ACTIVE' THEN
    UPDATE room SET available_beds = available_beds - 1
     WHERE room_code = NEW.room_code AND available_beds > 0;
    IF ROW_COUNT() = 0 THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'No beds available in this room';
    END IF;
  END IF;
END$$

-- ... vacating gives it back ...
CREATE TRIGGER trg_room_vacate_beds AFTER UPDATE ON room_allocation
FOR EACH ROW
BEGIN
  IF OLD.status = 'VACATED' AND NEW.status = 'ACTIVE' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'A vacated allocation cannot be re-opened; create a new allocation';
  END IF;
  IF OLD.status = 'ACTIVE' AND NEW.status = 'ACTIVE'
     AND (OLD.room_code <> NEW.room_code OR OLD.student_id <> NEW.student_id) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Vacate and allocate again instead of editing a live allocation';
  END IF;
  IF OLD.status = 'ACTIVE' AND NEW.status = 'VACATED' THEN
    UPDATE room SET available_beds = available_beds + 1 WHERE room_code = OLD.room_code;
  END IF;
END$$

-- ... and deleting a live allocation also frees the bed.
CREATE TRIGGER trg_room_allocation_del AFTER DELETE ON room_allocation
FOR EACH ROW
BEGIN
  IF OLD.status = 'ACTIVE' THEN
    UPDATE room SET available_beds = available_beds + 1 WHERE room_code = OLD.room_code;
  END IF;
END$$

DELIMITER ;

-- Student 360: program, current registration, primary guardian and hostel room.
CREATE VIEW vw_student_profile AS
SELECT s.student_id,
       s.enrollment_no,
       s.full_name,
       s.email,
       s.phone,
       s.gender,
       s.date_of_birth,
       s.status,
       p.program_name,
       p.dept_code,
       s.admission_year,
       sr.sem_no         AS current_sem_no,
       dv.division_name  AS division,
       b.batch_code      AS batch,
       sr.roll_no,
       g.guardian_name,
       g.relation        AS guardian_relation,
       g.phone           AS guardian_phone,
       ra.room_code      AS hostel_room
  FROM student s
  JOIN program p ON p.program_id = s.program_id
  LEFT JOIN semester_registration sr ON sr.student_id = s.student_id AND sr.semester_id = fn_current_semester()
  LEFT JOIN division dv ON dv.division_id = sr.division_id
  LEFT JOIN batch    b  ON b.batch_id     = sr.batch_id
  LEFT JOIN guardian g  ON g.student_id   = s.student_id AND g.is_primary = 1
  LEFT JOIN room_allocation ra ON ra.student_id = s.student_id AND ra.status = 'ACTIVE';
