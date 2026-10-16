-- PostgreSQL port of db/06_placement.sql (functions, procedures, triggers, views). MySQL original is unchanged.
-- See 00_admin_objects.sql for the porting conventions.

-- 'ELIGIBLE' or 'NOT ELIGIBLE: <first reason>'. Rules: active student, branch allowed, CGPA >= drive minimum
-- (G2), backlogs <= drive maximum, no overdue fees (G5). Backlog = a course whose best attempt is a fail grade.
CREATE FUNCTION fn_check_placement_eligibility(p_student_id CHAR, p_drive_id VARCHAR) RETURNS VARCHAR
LANGUAGE plpgsql STABLE AS $$
DECLARE
  v_status       VARCHAR(10);
  v_dept         CHAR(3);
  v_min_cgpa     NUMERIC(4,2);
  v_max_backlogs SMALLINT;
  v_cgpa         NUMERIC(4,2);
  v_backlogs     INTEGER;
  v_due          NUMERIC(10,2);
BEGIN
  SELECT s.status, p.dept_code INTO v_status, v_dept
    FROM student s JOIN program p ON p.program_id = s.program_id WHERE s.student_id = p_student_id;
  IF v_status IS NULL THEN RETURN 'NOT ELIGIBLE: unknown student'; END IF;
  IF v_status <> 'ACTIVE' THEN RETURN 'NOT ELIGIBLE: student is not active'; END IF;

  SELECT d.min_cgpa, d.max_backlogs INTO v_min_cgpa, v_max_backlogs
    FROM placement_drive d WHERE d.drive_id = p_drive_id;
  IF v_min_cgpa IS NULL THEN RETURN 'NOT ELIGIBLE: unknown drive'; END IF;

  IF NOT EXISTS (SELECT 1 FROM drive_eligible_branch b WHERE b.drive_id = p_drive_id AND b.dept_code = v_dept) THEN
    RETURN 'NOT ELIGIBLE: branch not allowed for this drive';
  END IF;

  v_cgpa := fn_calculate_cgpa(p_student_id);
  IF v_cgpa IS NULL THEN RETURN 'NOT ELIGIBLE: no published results yet'; END IF;
  IF v_cgpa < v_min_cgpa THEN
    RETURN 'NOT ELIGIBLE: CGPA ' || v_cgpa || ' is below the required ' || v_min_cgpa;
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
    RETURN 'NOT ELIGIBLE: ' || v_backlogs || ' backlog(s), drive allows ' || v_max_backlogs;
  END IF;

  v_due := fn_student_fee_due(p_student_id, NULL, 1);
  IF v_due > 0 THEN
    RETURN 'NOT ELIGIBLE: overdue fees of ' || v_due;
  END IF;
  RETURN 'ELIGIBLE';
END;
$$;

-- Registers a student for a drive only if the drive is open and the student is eligible; returns the application_id.
CREATE FUNCTION sp_register_for_drive(p_student_id CHAR, p_drive_id VARCHAR) RETURNS INTEGER
LANGUAGE plpgsql AS $$
DECLARE
  v_status   VARCHAR(10);
  v_deadline DATE;
  v_check    VARCHAR(120);
  v_app_id   INTEGER;
BEGIN
  SELECT d.status, d.registration_deadline INTO v_status, v_deadline
    FROM placement_drive d WHERE d.drive_id = p_drive_id;
  IF v_status IS NULL THEN
    RAISE EXCEPTION 'Unknown drive_id' USING ERRCODE = '45000';
  END IF;
  IF v_status <> 'OPEN' OR (v_deadline IS NOT NULL AND v_deadline < CURRENT_DATE) THEN
    RAISE EXCEPTION 'Registration for this drive is closed' USING ERRCODE = '45000';
  END IF;

  v_check := fn_check_placement_eligibility(p_student_id, p_drive_id);
  IF v_check <> 'ELIGIBLE' THEN
    RAISE EXCEPTION '%', v_check USING ERRCODE = '45000';
  END IF;

  INSERT INTO drive_application (drive_id, student_id) VALUES (p_drive_id, p_student_id)
  RETURNING application_id INTO v_app_id;
  RETURN v_app_id;
END;
$$;

-- Once a student has ACCEPTED an offer at or above the dream package (app_setting dream_package_lpa),
-- no further drive applications are allowed.
CREATE FUNCTION tf_one_offer_policy() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF EXISTS (SELECT 1
               FROM offer o JOIN drive_application a ON a.application_id = o.application_id
              WHERE a.student_id = NEW.student_id AND o.status = 'ACCEPTED'
                AND o.package_lpa >= fn_setting_num('dream_package_lpa')) THEN
    RAISE EXCEPTION 'One-offer policy: student already accepted an offer above the dream package'
      USING ERRCODE = '45000';
  END IF;
  RETURN NEW;
END;
$$;
CREATE TRIGGER trg_one_offer_policy BEFORE INSERT ON drive_application
  FOR EACH ROW EXECUTE FUNCTION tf_one_offer_policy();

-- Records the result of the next round: CLEARED moves the student on (the final round creates the offer),
-- REJECTED / ABSENT ends the application. Rounds must be recorded in order.
-- Usage:  SELECT * FROM sp_record_round_result(<application_id>, <round_no>, 'CLEARED', 82.5);
CREATE FUNCTION sp_record_round_result(
  p_application_id INTEGER,
  p_round_no       INTEGER,
  p_status         VARCHAR,
  p_score          NUMERIC DEFAULT NULL
) RETURNS TABLE (application_status VARCHAR, current_round INTEGER, offer_id INTEGER)
LANGUAGE plpgsql AS $$
#variable_conflict use_column
DECLARE
  v_drive      VARCHAR(12);
  v_app_status VARCHAR(12);
  v_current    SMALLINT;
  v_round_id   INTEGER;
  v_final      SMALLINT;
  v_pkg        NUMERIC(5,2);
  v_offer_id   INTEGER := NULL;
BEGIN
  SELECT a.drive_id, a.status, a.current_round INTO v_drive, v_app_status, v_current
    FROM drive_application a WHERE a.application_id = p_application_id FOR UPDATE;
  IF v_drive IS NULL THEN
    RAISE EXCEPTION 'Unknown application_id' USING ERRCODE = '45000';
  END IF;
  IF v_app_status NOT IN ('APPLIED','IN_PROGRESS') THEN
    RAISE EXCEPTION 'Application is no longer active' USING ERRCODE = '45000';
  END IF;
  IF p_round_no <> v_current + 1 THEN
    RAISE EXCEPTION 'Rounds must be recorded in order' USING ERRCODE = '45000';
  END IF;
  SELECT ir.round_id, ir.is_final INTO v_round_id, v_final
    FROM interview_round ir WHERE ir.drive_id = v_drive AND ir.round_no = p_round_no;
  IF v_round_id IS NULL THEN
    RAISE EXCEPTION 'This drive has no such round' USING ERRCODE = '45000';
  END IF;

  INSERT INTO round_result (application_id, round_id, status, score)
  VALUES (p_application_id, v_round_id, p_status, p_score);

  IF p_status = 'CLEARED' AND v_final = 1 THEN
    UPDATE drive_application SET status = 'SELECTED', current_round = p_round_no
     WHERE application_id = p_application_id;
    SELECT d.package_lpa INTO v_pkg FROM placement_drive d WHERE d.drive_id = v_drive;
    INSERT INTO offer (application_id, package_lpa) VALUES (p_application_id, v_pkg)
    RETURNING offer.offer_id INTO v_offer_id;
  ELSIF p_status = 'CLEARED' THEN
    UPDATE drive_application SET status = 'IN_PROGRESS', current_round = p_round_no
     WHERE application_id = p_application_id;
  ELSE
    UPDATE drive_application SET status = 'REJECTED', current_round = p_round_no
     WHERE application_id = p_application_id;
  END IF;

  RETURN QUERY
  SELECT a.status::VARCHAR, a.current_round::INTEGER, v_offer_id
    FROM drive_application a WHERE a.application_id = p_application_id;
END;
$$;

-- Student accepts / declines an offer. Accepting a dream-package offer withdraws their other open applications.
CREATE FUNCTION sp_respond_to_offer(p_offer_id INTEGER, p_accept INTEGER) RETURNS VOID
LANGUAGE plpgsql AS $$
DECLARE
  v_status  VARCHAR(10);
  v_pkg     NUMERIC(5,2);
  v_student CHAR(11);
BEGIN
  SELECT o.status, o.package_lpa, a.student_id INTO v_status, v_pkg, v_student
    FROM offer o JOIN drive_application a ON a.application_id = o.application_id
   WHERE o.offer_id = p_offer_id FOR UPDATE OF o;
  IF v_status IS NULL THEN
    RAISE EXCEPTION 'Unknown offer_id' USING ERRCODE = '45000';
  END IF;
  IF v_status <> 'OFFERED' THEN
    RAISE EXCEPTION 'Offer has already been answered or has expired' USING ERRCODE = '45000';
  END IF;

  UPDATE offer SET status = CASE WHEN p_accept = 1 THEN 'ACCEPTED' ELSE 'DECLINED' END, responded_on = NOW()
   WHERE offer_id = p_offer_id;
  IF p_accept = 1 AND v_pkg >= fn_setting_num('dream_package_lpa') THEN
    UPDATE drive_application SET status = 'WITHDRAWN'
     WHERE student_id = v_student AND status IN ('APPLIED','IN_PROGRESS');
  END IF;
END;
$$;

-- Placement statistics per academic department. Cohort = active students registered in the current
-- semester in semester 5 or above; "placed" = at least one ACCEPTED offer.
CREATE VIEW vw_placement_statistics AS
SELECT d.dept_code,
       d.dept_name,
       COALESCE(c.cohort, 0)                                      AS eligible_students,
       COALESCE(p.placed, 0)                                      AS placed_students,
       COALESCE(ROUND(100.0 * p.placed / NULLIF(c.cohort, 0), 2), 0) AS placed_pct,
       p.highest_package_lpa,
       p.average_package_lpa,
       COALESCE(p.offers_accepted, 0)                             AS offers_accepted
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
