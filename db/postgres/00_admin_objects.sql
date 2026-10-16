-- PostgreSQL port of db/00_admin.sql (functions, procedures, triggers). MySQL original is unchanged.
--
-- Porting notes (apply to every *_objects.sql):
--   * MySQL PROCEDUREs are PL/pgSQL FUNCTIONs here so Supabase can call them: supabase.rpc('sp_name', {...}).
--     OUT parameters become the return value. They run atomically: any error rolls back the whole call.
--   * SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'x'  ->  RAISE EXCEPTION 'x' USING ERRCODE = '45000'.
--   * Each MySQL trigger body is a trigger function named tf_<trigger name>.
--   * MySQL session variable @app_user  ->  current_setting('app.user', true); the backend sets it per request
--     with:  SET LOCAL app.user = '<username>';

-- Numeric business setting (75 attendance %, 7 escalation days, ...). NULL if the key is missing.
CREATE FUNCTION fn_setting_num(p_key VARCHAR) RETURNS NUMERIC(12,2)
LANGUAGE sql STABLE AS $$
  SELECT setting_value::NUMERIC(12,2) FROM app_setting WHERE setting_key = p_key;
$$;

-- The active teaching term. Uses the is_active flag; falls back to the term containing today.
CREATE FUNCTION fn_current_semester() RETURNS INTEGER
LANGUAGE plpgsql STABLE AS $$
DECLARE v_id INTEGER;
BEGIN
  SELECT semester_id INTO v_id FROM semester WHERE is_active = 1 LIMIT 1;
  IF v_id IS NULL THEN
    SELECT semester_id INTO v_id FROM semester
     WHERE CURRENT_DATE BETWEEN start_date AND end_date
     ORDER BY start_date DESC LIMIT 1;
  END IF;
  RETURN v_id;
END;
$$;

-- Creates a login account and its role mapping atomically; returns the new user_id.
-- p_ref_id: student_id for STUDENT, employee_id for FACULTY/ACCOUNTANT/PLACEMENT_OFFICER, NULL allowed for ADMIN.
-- (Extra p_password_hash vs. the plan: app_user.password_hash is NOT NULL and the backend does the bcrypt.)
CREATE FUNCTION sp_create_user_with_role(
  p_username      VARCHAR,
  p_email         VARCHAR,
  p_password_hash VARCHAR,
  p_role_name     VARCHAR,
  p_ref_id        VARCHAR DEFAULT NULL
) RETURNS INTEGER
LANGUAGE plpgsql AS $$
DECLARE
  v_role_id  SMALLINT;
  v_student  CHAR(11) := NULL;
  v_employee CHAR(7)  := NULL;
  v_user_id  INTEGER;
BEGIN
  SELECT r.role_id INTO v_role_id FROM role r WHERE r.role_name = p_role_name;
  IF v_role_id IS NULL THEN
    RAISE EXCEPTION 'Unknown role' USING ERRCODE = '45000';
  END IF;

  IF p_role_name = 'STUDENT' THEN
    IF p_ref_id IS NULL OR NOT EXISTS (SELECT 1 FROM student s WHERE s.student_id = p_ref_id) THEN
      RAISE EXCEPTION 'STUDENT role needs an existing student_id' USING ERRCODE = '45000';
    END IF;
    v_student := p_ref_id;
  ELSIF p_ref_id IS NOT NULL THEN
    IF NOT EXISTS (SELECT 1 FROM employee e WHERE e.employee_id = p_ref_id) THEN
      RAISE EXCEPTION 'employee_id does not exist' USING ERRCODE = '45000';
    END IF;
    v_employee := p_ref_id;
  END IF;

  INSERT INTO app_user (username, email, password_hash, student_id, employee_id)
  VALUES (p_username, p_email, p_password_hash, v_student, v_employee)
  RETURNING user_id INTO v_user_id;
  INSERT INTO user_role (user_id, role_id) VALUES (v_user_id, v_role_id);
  RETURN v_user_id;
END;
$$;

-- Publishes a notice and targets it by role and/or department (NULL = everyone); returns the notice_id.
CREATE FUNCTION sp_publish_notice(
  p_title     VARCHAR,
  p_body      TEXT,
  p_role_name VARCHAR,
  p_dept_code CHAR,
  p_posted_by INTEGER
) RETURNS INTEGER
LANGUAGE plpgsql AS $$
DECLARE
  v_role_id   SMALLINT := NULL;
  v_notice_id INTEGER;
BEGIN
  IF p_role_name IS NOT NULL THEN
    SELECT r.role_id INTO v_role_id FROM role r WHERE r.role_name = p_role_name;
    IF v_role_id IS NULL THEN
      RAISE EXCEPTION 'Unknown role' USING ERRCODE = '45000';
    END IF;
  END IF;
  IF p_dept_code IS NOT NULL AND NOT EXISTS (SELECT 1 FROM department d WHERE d.dept_code = p_dept_code) THEN
    RAISE EXCEPTION 'Unknown department' USING ERRCODE = '45000';
  END IF;

  INSERT INTO notice (title, body, posted_by) VALUES (p_title, p_body, p_posted_by)
  RETURNING notice_id INTO v_notice_id;
  INSERT INTO notice_target (notice_id, role_id, dept_code) VALUES (v_notice_id, v_role_id, p_dept_code);
  RETURN v_notice_id;
END;
$$;

-- Escalates every grievance that has been unresolved for >= grievance_escalation_days; returns how many.
-- The UPDATE only touches updated_at; tf_grievance_escalation decides and flips the status.
CREATE FUNCTION sp_escalate_overdue_grievances() RETURNS INTEGER
LANGUAGE plpgsql AS $$
DECLARE v_count INTEGER;
BEGIN
  UPDATE grievance
     SET updated_at = CURRENT_TIMESTAMP
   WHERE status IN ('OPEN','IN_PROGRESS')
     AND created_at <= NOW() - fn_setting_num('grievance_escalation_days') * INTERVAL '1 day';
  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count;
END;
$$;

-- Account activation changes are audited.
CREATE FUNCTION tf_user_audit() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF OLD.is_active IS DISTINCT FROM NEW.is_active THEN
    INSERT INTO user_audit_log (user_id, action, old_value, new_value, changed_by)
    VALUES (NEW.user_id, CASE WHEN NEW.is_active = 1 THEN 'REACTIVATED' ELSE 'DEACTIVATED' END,
            OLD.is_active::TEXT, NEW.is_active::TEXT,
            COALESCE(NULLIF(current_setting('app.user', true), ''), current_user));
  END IF;
  RETURN NEW;
END;
$$;
CREATE TRIGGER trg_user_audit AFTER UPDATE ON app_user
  FOR EACH ROW EXECUTE FUNCTION tf_user_audit();

-- Role grants / revocations are audited (companion triggers of trg_user_audit).
CREATE FUNCTION tf_user_role_audit_ins() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  INSERT INTO user_audit_log (user_id, action, old_value, new_value, changed_by)
  VALUES (NEW.user_id, 'ROLE_ASSIGNED', NULL,
          (SELECT role_name FROM role WHERE role_id = NEW.role_id),
          COALESCE(NULLIF(current_setting('app.user', true), ''), current_user));
  RETURN NEW;
END;
$$;
CREATE TRIGGER trg_user_role_audit_ins AFTER INSERT ON user_role
  FOR EACH ROW EXECUTE FUNCTION tf_user_role_audit_ins();

CREATE FUNCTION tf_user_role_audit_del() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  INSERT INTO user_audit_log (user_id, action, old_value, new_value, changed_by)
  VALUES (OLD.user_id, 'ROLE_REVOKED',
          (SELECT role_name FROM role WHERE role_id = OLD.role_id), NULL,
          COALESCE(NULLIF(current_setting('app.user', true), ''), current_user));
  RETURN OLD;
END;
$$;
CREATE TRIGGER trg_user_role_audit_del AFTER DELETE ON user_role
  FOR EACH ROW EXECUTE FUNCTION tf_user_role_audit_del();

-- A grievance that is still OPEN / IN_PROGRESS after the escalation window becomes ESCALATED
-- the next time it is touched (sp_escalate_overdue_grievances touches it daily).
CREATE FUNCTION tf_grievance_escalation() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF OLD.status IN ('OPEN','IN_PROGRESS') AND NEW.status IN ('OPEN','IN_PROGRESS')
     AND NEW.created_at <= NOW() - fn_setting_num('grievance_escalation_days') * INTERVAL '1 day' THEN
    NEW.status := 'ESCALATED';
    NEW.escalated_at := NOW();
  END IF;
  RETURN NEW;
END;
$$;
CREATE TRIGGER trg_grievance_escalation BEFORE UPDATE ON grievance
  FOR EACH ROW EXECUTE FUNCTION tf_grievance_escalation();

-- MySQL's ev_escalate_grievances (daily event) becomes a pg_cron job when the extension is available.
-- If it is not, call sp_escalate_overdue_grievances() from the backend or enable pg_cron in the Supabase dashboard.
DO $$
BEGIN
  CREATE EXTENSION IF NOT EXISTS pg_cron;
  PERFORM cron.schedule('ev_escalate_grievances', '0 1 * * *', 'SELECT sp_escalate_overdue_grievances()');
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'pg_cron not scheduled (%). Call sp_escalate_overdue_grievances() manually.', SQLERRM;
END;
$$;
