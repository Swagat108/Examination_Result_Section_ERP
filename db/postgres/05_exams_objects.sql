-- PostgreSQL port of db/05_exams.sql (functions, procedures, triggers, views). MySQL original is unchanged.
-- See 00_admin_objects.sql for the porting conventions.

-- Credit-weighted CGPA over all the student's courses (best attempt per course counts).
-- NULL when the student has no published result yet.
CREATE FUNCTION fn_calculate_cgpa(p_student_id CHAR) RETURNS NUMERIC(4,2)
LANGUAGE sql STABLE AS $$
  SELECT ROUND(SUM(t.credits * t.gp)::NUMERIC / SUM(t.credits), 2)::NUMERIC(4,2)
    FROM (SELECT c.course_code, c.credits, MAX(g.grade_point) AS gp
            FROM result r
            JOIN course_offering o ON o.offering_id = r.offering_id
            JOIN course c          ON c.course_code = o.course_code
            JOIN grade_scale g     ON g.grade = r.grade
           WHERE r.student_id = p_student_id
           GROUP BY c.course_code, c.credits) t;
$$;

-- SGPA: the same weighting restricted to one semester.
CREATE FUNCTION fn_calculate_sgpa(p_student_id CHAR, p_semester_id INTEGER) RETURNS NUMERIC(4,2)
LANGUAGE sql STABLE AS $$
  SELECT ROUND(SUM(c.credits * g.grade_point)::NUMERIC / SUM(c.credits), 2)::NUMERIC(4,2)
    FROM result r
    JOIN course_offering o ON o.offering_id = r.offering_id AND o.semester_id = p_semester_id
    JOIN course c          ON c.course_code = o.course_code
    JOIN grade_scale g     ON g.grade = r.grade
   WHERE r.student_id = p_student_id;
$$;

-- Registration is refused when attendance in that course is below min_attendance_pct (75).
CREATE FUNCTION sp_assert_exam_attendance(p_student_id CHAR, p_offering_id INTEGER) RETURNS VOID
LANGUAGE plpgsql AS $$
DECLARE
  v_pct NUMERIC(5,2);
  v_min NUMERIC(12,2);
  v_msg VARCHAR(128);
BEGIN
  v_pct := fn_attendance_percentage(p_student_id, p_offering_id);
  v_min := fn_setting_num('min_attendance_pct');
  IF v_pct < v_min THEN
    v_msg := 'Exam registration blocked: attendance ' || v_pct || '% is below ' || v_min || '%';
    RAISE EXCEPTION '%', v_msg USING ERRCODE = '45000';
  END IF;
END;
$$;

-- One trigger function serves the MySQL pair trg_exam_registration_attendance (INSERT) and
-- trg_exam_registration_attendance_upd (UPDATE).
CREATE FUNCTION tf_exam_registration_attendance() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.status = 'REGISTERED' AND (TG_OP = 'INSERT' OR OLD.status <> 'REGISTERED') THEN
    PERFORM sp_assert_exam_attendance(NEW.student_id, NEW.offering_id);
  END IF;
  RETURN NEW;
END;
$$;
CREATE TRIGGER trg_exam_registration_attendance BEFORE INSERT ON exam_registration
  FOR EACH ROW EXECUTE FUNCTION tf_exam_registration_attendance();
CREATE TRIGGER trg_exam_registration_attendance_upd BEFORE UPDATE ON exam_registration
  FOR EACH ROW EXECUTE FUNCTION tf_exam_registration_attendance();

-- Marks cannot exceed the maximum of that scheduled paper (serves trg_marks_max_check and _upd).
CREATE FUNCTION tf_marks_max_check() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE v_max SMALLINT;
BEGIN
  SELECT es.max_marks INTO v_max FROM exam_schedule es
   WHERE es.exam_id = NEW.exam_id AND es.offering_id = NEW.offering_id;
  IF NEW.marks_obtained > v_max THEN
    RAISE EXCEPTION 'Marks exceed the maximum marks of this paper' USING ERRCODE = '45000';
  END IF;
  RETURN NEW;
END;
$$;
CREATE TRIGGER trg_marks_max_check BEFORE INSERT ON marks
  FOR EACH ROW EXECUTE FUNCTION tf_marks_max_check();
CREATE TRIGGER trg_marks_max_check_upd BEFORE UPDATE ON marks
  FOR EACH ROW EXECUTE FUNCTION tf_marks_max_check();

-- Hall tickets for students who are registered AND still eligible:
--   attendance >= minimum in every registered course, and no unpaid EXAM-type fee.
-- Usage:  SELECT * FROM sp_generate_hall_tickets('<exam_id>');
CREATE FUNCTION sp_generate_hall_tickets(p_exam_id VARCHAR)
RETURNS TABLE (hall_tickets_issued INTEGER, registered_but_ineligible INTEGER)
LANGUAGE plpgsql AS $$
#variable_conflict use_column
DECLARE
  v_issued   INTEGER := 0;
  v_skipped  INTEGER := 0;
  v_min      NUMERIC(12,2);
  v_offset   INTEGER := 0;
  v_eligible TEXT[];
BEGIN
  IF NOT EXISTS (SELECT 1 FROM exam e WHERE e.exam_id = p_exam_id) THEN
    RAISE EXCEPTION 'Unknown exam_id' USING ERRCODE = '45000';
  END IF;
  v_min := fn_setting_num('min_attendance_pct');

  -- eligible = registered students with no failing course attendance and no unpaid exam fee
  SELECT COALESCE(array_agg(x.sid), '{}') INTO v_eligible
    FROM (SELECT r.student_id::TEXT AS sid
            FROM exam_registration r
           WHERE r.exam_id = p_exam_id AND r.status = 'REGISTERED'
           GROUP BY r.student_id
          HAVING MIN(fn_attendance_percentage(r.student_id, r.offering_id)) >= v_min
             AND fn_student_fee_due(r.student_id, 'EXAM', 0) = 0) x;

  SELECT COUNT(DISTINCT r.student_id) - cardinality(v_eligible) INTO v_skipped
    FROM exam_registration r WHERE r.exam_id = p_exam_id AND r.status = 'REGISTERED';
  SELECT COUNT(*) INTO v_offset FROM hall_ticket h WHERE h.exam_id = p_exam_id;

  INSERT INTO hall_ticket (hall_ticket_no, exam_id, student_id, seat_no)
  SELECT 'HT-' || p_exam_id || '-' || LPAD((v_offset + x.n)::TEXT, 4, '0'), p_exam_id, x.sid,
         'S' || LPAD((v_offset + x.n)::TEXT, 4, '0')
    FROM (SELECT e.sid, ROW_NUMBER() OVER (ORDER BY e.sid) AS n
            FROM unnest(v_eligible) AS e(sid)
           WHERE NOT EXISTS (SELECT 1 FROM hall_ticket h
                              WHERE h.exam_id = p_exam_id AND h.student_id::TEXT = e.sid)) x;
  GET DIAGNOSTICS v_issued = ROW_COUNT;

  RETURN QUERY SELECT v_issued, v_skipped;
END;
$$;

-- Converts marks to grades: for every course scheduled in the exam, the marks of ALL exams of that
-- semester (ISE + MSE + ESE ...) are added up, the percentage is looked up in grade_scale and stored in
-- `result`. Absent counts as 0. Re-runnable (results of those courses are rebuilt).
-- Usage:  SELECT * FROM sp_publish_results('<exam_id>');
CREATE FUNCTION sp_publish_results(p_exam_id VARCHAR)
RETURNS TABLE (results_published INTEGER, passed INTEGER, failed INTEGER)
LANGUAGE plpgsql AS $$
#variable_conflict use_column
DECLARE
  v_sem  INTEGER;
  v_rows INTEGER := 0;
  v_pass INTEGER := 0;
  v_fail INTEGER := 0;
BEGIN
  SELECT e.semester_id INTO v_sem FROM exam e WHERE e.exam_id = p_exam_id;
  IF v_sem IS NULL THEN
    RAISE EXCEPTION 'Unknown exam_id' USING ERRCODE = '45000';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM marks m WHERE m.exam_id = p_exam_id) THEN
    RAISE EXCEPTION 'No marks have been entered for this exam' USING ERRCODE = '45000';
  END IF;

  DELETE FROM result r
   WHERE r.offering_id IN (SELECT es.offering_id FROM exam_schedule es WHERE es.exam_id = p_exam_id)
     AND r.student_id  IN (SELECT m.student_id FROM marks m WHERE m.exam_id = p_exam_id);

  INSERT INTO result (student_id, offering_id, total_marks, max_marks, grade)
  SELECT t.student_id, t.offering_id, t.total, t.max_total,
         (SELECT g.grade FROM grade_scale g
           WHERE g.min_pct <= ROUND(t.total * 100.0 / t.max_total, 2)
           ORDER BY g.min_pct DESC LIMIT 1)
    FROM (SELECT m.student_id, m.offering_id,
                 SUM(COALESCE(m.marks_obtained, 0)) AS total,
                 SUM(es.max_marks)                  AS max_total
            FROM marks m
            JOIN exam_schedule es ON es.exam_id = m.exam_id AND es.offering_id = m.offering_id
            JOIN exam e           ON e.exam_id = m.exam_id AND e.semester_id = v_sem
           WHERE m.offering_id IN (SELECT es2.offering_id FROM exam_schedule es2 WHERE es2.exam_id = p_exam_id)
             AND m.student_id  IN (SELECT m2.student_id FROM marks m2 WHERE m2.exam_id = p_exam_id)
           GROUP BY m.student_id, m.offering_id) t;
  GET DIAGNOSTICS v_rows = ROW_COUNT;

  UPDATE exam SET status = 'RESULTS_PUBLISHED' WHERE exam_id = p_exam_id;
  SELECT COALESCE(SUM(CASE WHEN g.is_pass = 1 THEN 1 ELSE 0 END), 0),
         COALESCE(SUM(CASE WHEN g.is_pass = 0 THEN 1 ELSE 0 END), 0)
    INTO v_pass, v_fail
    FROM result r JOIN grade_scale g ON g.grade = r.grade
   WHERE r.offering_id IN (SELECT es.offering_id FROM exam_schedule es WHERE es.exam_id = p_exam_id)
     AND r.student_id  IN (SELECT m.student_id FROM marks m WHERE m.exam_id = p_exam_id);

  RETURN QUERY SELECT v_rows, v_pass, v_fail;
END;
$$;

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
               SUM(c.credits)                                                       AS credits,
               ROUND(SUM(c.credits * g.grade_point)::NUMERIC / SUM(c.credits), 2)   AS sgpa,
               fn_calculate_cgpa(s.student_id)                                      AS cgpa
          FROM result r
          JOIN student s         ON s.student_id  = r.student_id
          JOIN course_offering o ON o.offering_id = r.offering_id
          JOIN course c          ON c.course_code = o.course_code
          JOIN grade_scale g     ON g.grade       = r.grade
         GROUP BY s.program_id, o.semester_id, s.student_id, s.full_name) t
  JOIN semester sm      ON sm.semester_id = t.semester_id
  JOIN academic_year ay ON ay.academic_year_id = sm.academic_year_id;
