-- PostgreSQL port of db/01_academics.sql (procedures, triggers, functions, views). MySQL original is unchanged.
-- See 00_admin_objects.sql for the porting conventions.

-- Creates offerings for the curriculum of a term.
--   p_sem_no NULL  -> every curriculum semester of the right parity (odd/even)
--   p_sem_no = n   -> only that semester number
-- CORE courses get one offering per division of that program/year (or one shared offering if the
-- program has no divisions yet); electives / honors / MDM get one shared offering. Re-runnable.
-- Usage:  SELECT * FROM sp_generate_course_offerings(<semester_id>, NULL);
CREATE FUNCTION sp_generate_course_offerings(p_semester_id INTEGER, p_sem_no INTEGER DEFAULT NULL)
RETURNS TABLE (core_offerings_created INTEGER, shared_offerings_created INTEGER)
LANGUAGE plpgsql AS $$
DECLARE
  v_term   VARCHAR(4);
  v_ay     INTEGER;
  v_parity INTEGER;
  v_core   INTEGER := 0;
  v_shared INTEGER := 0;
BEGIN
  SELECT s.term, s.academic_year_id INTO v_term, v_ay FROM semester s WHERE s.semester_id = p_semester_id;
  IF v_term IS NULL THEN
    RAISE EXCEPTION 'Unknown semester_id' USING ERRCODE = '45000';
  END IF;
  v_parity := CASE WHEN v_term = 'ODD' THEN 1 ELSE 0 END;

  -- core courses, one offering per division
  INSERT INTO course_offering (course_code, semester_id, division_id, max_seats)
  SELECT cu.course_code, p_semester_id, d.division_id, 90
    FROM curriculum cu
    JOIN course   c ON c.course_code = cu.course_code AND c.category = 'CORE'
    JOIN division d ON d.program_id = cu.program_id AND d.academic_year_id = v_ay
                   AND d.year_of_study = CEIL(cu.sem_no / 2.0)
   WHERE MOD(cu.sem_no, 2) = v_parity AND (p_sem_no IS NULL OR cu.sem_no = p_sem_no)
     AND NOT EXISTS (SELECT 1 FROM course_offering o
                      WHERE o.course_code = cu.course_code AND o.semester_id = p_semester_id
                        AND o.division_id = d.division_id);
  GET DIAGNOSTICS v_core = ROW_COUNT;

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
                                    AND d.year_of_study = CEIL(cu.sem_no / 2.0)))) x
   WHERE NOT EXISTS (SELECT 1 FROM course_offering o
                      WHERE o.course_code = x.course_code AND o.semester_id = p_semester_id
                        AND o.division_id IS NULL)
   GROUP BY x.course_code;
  GET DIAGNOSTICS v_shared = ROW_COUNT;

  RETURN QUERY SELECT v_core, v_shared;
END;
$$;

-- Raises an error if the proposed slot double-books the faculty member or the room in the same term.
CREATE FUNCTION sp_assert_no_timetable_clash(
  p_slot_id INTEGER, p_offering_id INTEGER, p_employee_id CHAR,
  p_classroom_id INTEGER, p_day VARCHAR, p_start TIME, p_end TIME
) RETURNS VOID
LANGUAGE plpgsql AS $$
DECLARE v_sem INTEGER;
BEGIN
  SELECT o.semester_id INTO v_sem FROM course_offering o WHERE o.offering_id = p_offering_id;

  IF EXISTS (SELECT 1 FROM timetable_slot t JOIN course_offering o ON o.offering_id = t.offering_id
              WHERE o.semester_id = v_sem AND t.day_of_week = p_day AND t.slot_id <> COALESCE(p_slot_id, 0)
                AND t.employee_id = p_employee_id AND t.start_time < p_end AND t.end_time > p_start) THEN
    RAISE EXCEPTION 'Timetable clash: faculty already teaching at that time' USING ERRCODE = '45000';
  END IF;
  IF EXISTS (SELECT 1 FROM timetable_slot t JOIN course_offering o ON o.offering_id = t.offering_id
              WHERE o.semester_id = v_sem AND t.day_of_week = p_day AND t.slot_id <> COALESCE(p_slot_id, 0)
                AND t.classroom_id = p_classroom_id AND t.start_time < p_end AND t.end_time > p_start) THEN
    RAISE EXCEPTION 'Timetable clash: classroom already booked at that time' USING ERRCODE = '45000';
  END IF;
END;
$$;

-- One trigger function serves the MySQL pair trg_timetable_clash (INSERT) and trg_timetable_clash_upd (UPDATE).
CREATE FUNCTION tf_timetable_clash() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  PERFORM sp_assert_no_timetable_clash(
    CASE WHEN TG_OP = 'UPDATE' THEN OLD.slot_id END,
    NEW.offering_id, NEW.employee_id, NEW.classroom_id, NEW.day_of_week, NEW.start_time, NEW.end_time);
  RETURN NEW;
END;
$$;
CREATE TRIGGER trg_timetable_clash BEFORE INSERT ON timetable_slot
  FOR EACH ROW EXECUTE FUNCTION tf_timetable_clash();
CREATE TRIGGER trg_timetable_clash_upd BEFORE UPDATE ON timetable_slot
  FOR EACH ROW EXECUTE FUNCTION tf_timetable_clash();

-- Teaching hours per week of a faculty member in the active semester.
CREATE FUNCTION fn_faculty_weekly_load(p_employee_id CHAR) RETURNS NUMERIC(5,2)
LANGUAGE sql STABLE AS $$
  SELECT COALESCE(ROUND((SUM(EXTRACT(EPOCH FROM (t.end_time - t.start_time))) / 3600)::NUMERIC, 2), 0)::NUMERIC(5,2)
    FROM timetable_slot t
    JOIN course_offering o ON o.offering_id = t.offering_id
   WHERE t.employee_id = p_employee_id AND o.semester_id = fn_current_semester();
$$;

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
