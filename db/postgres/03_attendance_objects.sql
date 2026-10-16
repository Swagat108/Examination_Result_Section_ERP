-- PostgreSQL port of db/03_attendance.sql (functions, procedures, triggers, views). MySQL original is unchanged.
-- See 00_admin_objects.sql for the porting conventions.

-- Attendance % of a student in one course offering (PRESENT + LATE over sessions HELD).
-- Returns 100.00 while no session has been recorded, so nobody is a "defaulter" before classes start.
CREATE FUNCTION fn_attendance_percentage(p_student_id CHAR, p_offering_id INTEGER) RETURNS NUMERIC(5,2)
LANGUAGE plpgsql STABLE AS $$
DECLARE
  v_total    INTEGER := 0;
  v_attended INTEGER := 0;
BEGIN
  SELECT COUNT(*), COALESCE(SUM(CASE WHEN sa.status IN ('PRESENT','LATE') THEN 1 ELSE 0 END), 0)
    INTO v_total, v_attended
    FROM student_attendance sa
    JOIN class_session cs ON cs.session_id = sa.session_id AND cs.status = 'HELD'
   WHERE sa.student_id = p_student_id AND cs.offering_id = p_offering_id;
  IF v_total = 0 THEN
    RETURN 100.00;
  END IF;
  RETURN ROUND(v_attended * 100.0 / v_total, 2);
END;
$$;

-- Marks the whole class PRESENT, then flips the absentees, in one transaction.
--   p_absent_list: JSON array of student ids, e.g. '["2024ETC0362","2024ETC0209"]' (or '[]')
-- The roster is the students enrolled in the offering (and in the session's batch for practicals).
-- Usage:  SELECT * FROM sp_mark_attendance_bulk(<session_id>, '["2024ETC0362"]', 'EMP0001');
CREATE FUNCTION sp_mark_attendance_bulk(p_session_id INTEGER, p_absent_list JSONB, p_marked_by CHAR)
RETURNS TABLE (present INTEGER, absent INTEGER, roster_size INTEGER)
LANGUAGE plpgsql AS $$
DECLARE
  v_offering INTEGER;
  v_batch    INTEGER;
  v_sem      INTEGER;
  v_status   VARCHAR(10);
  v_roster   TEXT[];
  v_absentees TEXT[];
  v_present  INTEGER := 0;
  v_absent   INTEGER := 0;
BEGIN
  SELECT cs.offering_id, cs.batch_id, o.semester_id, cs.status
    INTO v_offering, v_batch, v_sem, v_status
    FROM class_session cs JOIN course_offering o ON o.offering_id = cs.offering_id
   WHERE cs.session_id = p_session_id;
  IF v_offering IS NULL THEN
    RAISE EXCEPTION 'Unknown session_id' USING ERRCODE = '45000';
  END IF;
  IF v_status = 'CANCELLED' THEN
    RAISE EXCEPTION 'Cannot mark attendance for a cancelled session' USING ERRCODE = '45000';
  END IF;
  IF p_absent_list IS NULL OR jsonb_typeof(p_absent_list) <> 'array' THEN
    RAISE EXCEPTION 'p_absent_list must be a JSON array of student ids' USING ERRCODE = '45000';
  END IF;

  -- roster for this session
  SELECT COALESCE(array_agg(ce.student_id::TEXT), '{}') INTO v_roster
    FROM course_enrollment ce
    LEFT JOIN semester_registration sr ON sr.student_id = ce.student_id AND sr.semester_id = v_sem
   WHERE ce.offering_id = v_offering AND ce.status = 'ENROLLED'
     AND (v_batch IS NULL OR sr.batch_id = v_batch);

  v_absentees := ARRAY(SELECT jsonb_array_elements_text(p_absent_list));

  -- every absentee must be on the roster
  IF EXISTS (SELECT 1 FROM unnest(v_absentees) a WHERE a <> ALL (v_roster)) THEN
    RAISE EXCEPTION 'Absent list contains a student who is not enrolled in this session' USING ERRCODE = '45000';
  END IF;

  DELETE FROM student_attendance WHERE session_id = p_session_id;
  INSERT INTO student_attendance (session_id, student_id, status, marked_by)
  SELECT p_session_id, r, 'PRESENT', p_marked_by FROM unnest(v_roster) r;
  GET DIAGNOSTICS v_present = ROW_COUNT;
  UPDATE student_attendance sa
     SET status = 'ABSENT'
   WHERE sa.session_id = p_session_id AND sa.student_id::TEXT = ANY (v_absentees);
  GET DIAGNOSTICS v_absent = ROW_COUNT;
  UPDATE class_session SET status = 'HELD' WHERE session_id = p_session_id AND status = 'SCHEDULED';

  RETURN QUERY SELECT v_present - v_absent, v_absent, v_present;
END;
$$;

-- Remaining leave days of an employee for a leave type (e.g. 'CL') in the current calendar year.
CREATE FUNCTION fn_leave_balance(p_employee_id CHAR, p_leave_code VARCHAR) RETURNS NUMERIC(4,1)
LANGUAGE sql STABLE AS $$
  SELECT COALESCE(
    (SELECT lb.balance
       FROM leave_balance lb JOIN leave_type lt ON lt.leave_type_id = lb.leave_type_id
      WHERE lb.employee_id = p_employee_id AND lt.leave_code = p_leave_code
        AND lb.leave_year = EXTRACT(YEAR FROM CURRENT_DATE)), 0)::NUMERIC(4,1);
$$;

-- Approval deducts the days from leave_balance (paid leave types) and is rejected when the
-- balance is too low; cancelling an approved leave gives the days back.
CREATE FUNCTION tf_leave_approval() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE
  v_paid SMALLINT;
  v_days INTEGER;
  v_rows INTEGER;
BEGIN
  v_days := (NEW.to_date - NEW.from_date) + 1;
  SELECT lt.is_paid INTO v_paid FROM leave_type lt WHERE lt.leave_type_id = NEW.leave_type_id;

  IF OLD.status <> 'APPROVED' AND NEW.status = 'APPROVED' AND v_paid = 1 THEN
    UPDATE leave_balance
       SET used = used + v_days
     WHERE employee_id = NEW.employee_id AND leave_type_id = NEW.leave_type_id
       AND leave_year = EXTRACT(YEAR FROM NEW.from_date) AND balance >= v_days;
    GET DIAGNOSTICS v_rows = ROW_COUNT;
    IF v_rows = 0 THEN
      RAISE EXCEPTION 'Insufficient leave balance - leave cannot be approved' USING ERRCODE = '45000';
    END IF;
  ELSIF OLD.status = 'APPROVED' AND NEW.status = 'CANCELLED' AND v_paid = 1 THEN
    UPDATE leave_balance
       SET used = GREATEST(used - v_days, 0)
     WHERE employee_id = NEW.employee_id AND leave_type_id = NEW.leave_type_id
       AND leave_year = EXTRACT(YEAR FROM NEW.from_date);
  END IF;
  RETURN NEW;
END;
$$;
CREATE TRIGGER trg_leave_approval AFTER UPDATE ON leave_application
  FOR EACH ROW EXECUTE FUNCTION tf_leave_approval();

-- Students below the minimum attendance (app_setting min_attendance_pct, 75) in any course.
CREATE VIEW vw_attendance_defaulters AS
SELECT s.student_id,
       s.full_name,
       c.course_code,
       c.course_title,
       o.offering_id,
       COUNT(*)                                                                         AS sessions_held,
       SUM(CASE WHEN sa.status IN ('PRESENT','LATE') THEN 1 ELSE 0 END)                 AS sessions_attended,
       ROUND(100.0 * SUM(CASE WHEN sa.status IN ('PRESENT','LATE') THEN 1 ELSE 0 END) / COUNT(*), 2) AS attendance_pct
  FROM student_attendance sa
  JOIN class_session   cs ON cs.session_id = sa.session_id AND cs.status = 'HELD'
  JOIN course_offering o  ON o.offering_id = cs.offering_id
  JOIN course          c  ON c.course_code = o.course_code
  JOIN student         s  ON s.student_id  = sa.student_id
 GROUP BY s.student_id, s.full_name, c.course_code, c.course_title, o.offering_id
HAVING 100.0 * SUM(CASE WHEN sa.status IN ('PRESENT','LATE') THEN 1 ELSE 0 END) / COUNT(*)
       < fn_setting_num('min_attendance_pct');
