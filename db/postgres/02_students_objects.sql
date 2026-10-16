-- PostgreSQL port of db/02_students.sql (functions, procedures, triggers, views). MySQL original is unchanged.
-- See 00_admin_objects.sql for the porting conventions.

-- Next student id for a year + department, e.g. fn_generate_student_id(2026,'ETC') -> 2026ETC0001
CREATE FUNCTION fn_generate_student_id(p_year INTEGER, p_dept_code CHAR) RETURNS CHAR(11)
LANGUAGE plpgsql STABLE AS $$
DECLARE v_next INTEGER;
BEGIN
  SELECT COALESCE(MAX(SUBSTRING(s.student_id FROM 8 FOR 4)::INTEGER), 0) + 1 INTO v_next
    FROM student s
   WHERE s.student_id LIKE p_year::TEXT || trim(p_dept_code) || '%';
  IF v_next > 9999 THEN
    RAISE EXCEPTION 'Student serial exhausted for this year and department' USING ERRCODE = '45000';
  END IF;
  RETURN p_year::TEXT || trim(p_dept_code) || LPAD(v_next::TEXT, 4, '0');
END;
$$;

-- Admits a student: student + primary guardian + admission row in one transaction; returns the student_id.
-- A transaction-scoped advisory lock (MySQL GET_LOCK) serialises id generation so two admissions never
-- get the same serial.
CREATE FUNCTION sp_admit_student(
  p_enrollment_no  VARCHAR,
  p_full_name      VARCHAR,
  p_email          VARCHAR,
  p_phone          VARCHAR,
  p_gender         VARCHAR,
  p_dob            DATE,
  p_program_id     INTEGER,
  p_admission_year INTEGER,
  p_admission_type VARCHAR,
  p_guardian_name  VARCHAR,
  p_guardian_rel   VARCHAR,
  p_guardian_phone VARCHAR
) RETURNS CHAR(11)
LANGUAGE plpgsql AS $$
DECLARE
  v_dept       CHAR(3);
  v_ay         INTEGER;
  v_student_id CHAR(11);
BEGIN
  SELECT p.dept_code INTO v_dept FROM program p WHERE p.program_id = p_program_id;
  IF v_dept IS NULL THEN
    RAISE EXCEPTION 'Unknown program_id' USING ERRCODE = '45000';
  END IF;
  SELECT a.academic_year_id INTO v_ay FROM academic_year a
   WHERE EXTRACT(YEAR FROM a.start_date) = p_admission_year LIMIT 1;
  IF v_ay IS NULL THEN
    RAISE EXCEPTION 'No academic year starts in the admission year' USING ERRCODE = '45000';
  END IF;

  PERFORM pg_advisory_xact_lock(hashtext('erp_student_id'));

  v_student_id := fn_generate_student_id(p_admission_year, v_dept);
  INSERT INTO student (student_id, enrollment_no, full_name, email, phone, gender, date_of_birth,
                       program_id, admission_year)
  VALUES (v_student_id, p_enrollment_no, p_full_name,
          COALESCE(p_email, LOWER(p_enrollment_no) || '@students.erp.local'),
          p_phone, p_gender, p_dob, p_program_id, p_admission_year);
  IF p_guardian_name IS NOT NULL THEN
    INSERT INTO guardian (student_id, guardian_name, relation, phone, is_primary)
    VALUES (v_student_id, p_guardian_name, COALESCE(p_guardian_rel, 'GUARDIAN'), p_guardian_phone, 1);
  END IF;
  INSERT INTO admission (student_id, program_id, academic_year_id, admission_type, admission_date)
  VALUES (v_student_id, p_program_id, v_ay, COALESCE(p_admission_type, 'REGULAR'), CURRENT_DATE);
  RETURN v_student_id;
END;
$$;

-- Enrolls every registered student of a program into the offerings of their semester:
--   * CORE courses of their division (curriculum of the program/semester no.)
--   * the elective / honors / MDM courses they picked (elective_selection)
-- All-or-nothing: if any offering would exceed max_seats the whole run is rolled back (the exception
-- aborts the function, undoing every insert).
-- Usage:  SELECT * FROM sp_bulk_enroll_students(<program_id>, <semester_id>);
CREATE FUNCTION sp_bulk_enroll_students(p_program_id INTEGER, p_semester_id INTEGER)
RETURNS TABLE (core_enrollments_created INTEGER, elective_enrollments_created INTEGER)
LANGUAGE plpgsql AS $$
DECLARE
  v_core INTEGER := 0;
  v_elec INTEGER := 0;
  v_full VARCHAR(8);
BEGIN
  IF NOT EXISTS (SELECT 1 FROM program p WHERE p.program_id = p_program_id) THEN
    RAISE EXCEPTION 'Unknown program_id' USING ERRCODE = '45000';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM semester s WHERE s.semester_id = p_semester_id) THEN
    RAISE EXCEPTION 'Unknown semester_id' USING ERRCODE = '45000';
  END IF;

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
  GET DIAGNOSTICS v_core = ROW_COUNT;

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
  GET DIAGNOSTICS v_elec = ROW_COUNT;

  -- capacity guard
  SELECT o.course_code INTO v_full
    FROM course_offering o
    JOIN course_enrollment ce ON ce.offering_id = o.offering_id AND ce.status = 'ENROLLED'
   WHERE o.semester_id = p_semester_id
   GROUP BY o.offering_id, o.course_code, o.max_seats
  HAVING COUNT(*) > o.max_seats
   LIMIT 1;
  IF v_full IS NOT NULL THEN
    RAISE EXCEPTION 'Bulk enrollment rolled back: an offering exceeds max_seats' USING ERRCODE = '45000';
  END IF;

  RETURN QUERY SELECT v_core, v_elec;
END;
$$;

-- Hostel beds: allocation takes a bed (blocked at 0) ...
CREATE FUNCTION tf_room_allocation_beds() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE v_rows INTEGER;
BEGIN
  IF NEW.status = 'ACTIVE' THEN
    UPDATE room SET available_beds = available_beds - 1
     WHERE room_code = NEW.room_code AND available_beds > 0;
    GET DIAGNOSTICS v_rows = ROW_COUNT;
    IF v_rows = 0 THEN
      RAISE EXCEPTION 'No beds available in this room' USING ERRCODE = '45000';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;
CREATE TRIGGER trg_room_allocation_beds BEFORE INSERT ON room_allocation
  FOR EACH ROW EXECUTE FUNCTION tf_room_allocation_beds();

-- ... vacating gives it back ...
CREATE FUNCTION tf_room_vacate_beds() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF OLD.status = 'VACATED' AND NEW.status = 'ACTIVE' THEN
    RAISE EXCEPTION 'A vacated allocation cannot be re-opened; create a new allocation' USING ERRCODE = '45000';
  END IF;
  IF OLD.status = 'ACTIVE' AND NEW.status = 'ACTIVE'
     AND (OLD.room_code <> NEW.room_code OR OLD.student_id <> NEW.student_id) THEN
    RAISE EXCEPTION 'Vacate and allocate again instead of editing a live allocation' USING ERRCODE = '45000';
  END IF;
  IF OLD.status = 'ACTIVE' AND NEW.status = 'VACATED' THEN
    UPDATE room SET available_beds = available_beds + 1 WHERE room_code = OLD.room_code;
  END IF;
  RETURN NEW;
END;
$$;
CREATE TRIGGER trg_room_vacate_beds AFTER UPDATE ON room_allocation
  FOR EACH ROW EXECUTE FUNCTION tf_room_vacate_beds();

-- ... and deleting a live allocation also frees the bed.
CREATE FUNCTION tf_room_allocation_del() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF OLD.status = 'ACTIVE' THEN
    UPDATE room SET available_beds = available_beds + 1 WHERE room_code = OLD.room_code;
  END IF;
  RETURN OLD;
END;
$$;
CREATE TRIGGER trg_room_allocation_del AFTER DELETE ON room_allocation
  FOR EACH ROW EXECUTE FUNCTION tf_room_allocation_del();

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
