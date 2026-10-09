-- =====================================================================
-- 07_integration.sql   |  cross-module links (owned by the Team Leaders)
-- Everything that needs tables from more than one module and therefore
-- cannot live in an earlier script:
--   * app_user -> student / employee   (integration map rows 5)
--   * vw_university_dashboard          (G1 KPIs across all modules)
-- =====================================================================
SET NAMES utf8mb4;

ALTER TABLE app_user
  ADD CONSTRAINT fk_app_user_student  FOREIGN KEY (student_id)  REFERENCES student (student_id),
  ADD CONSTRAINT fk_app_user_employee FOREIGN KEY (employee_id) REFERENCES employee (employee_id);

-- One row per academic department with KPIs from every module, and two RANK() columns.
-- Every metric is aggregated in its own derived table first, so joins never multiply rows.
CREATE VIEW vw_university_dashboard AS
SELECT d.dept_code,
       d.dept_name,
       IFNULL(st.students, 0)          AS active_students,
       IFNULL(fa.faculty, 0)           AS active_faculty,
       IFNULL(co.courses, 0)           AS courses_in_catalogue,
       cg.avg_cgpa,
       att.avg_attendance_pct,
       IFNULL(fe.fee_collected, 0)     AS fee_collected,
       IFNULL(fo.fee_outstanding, 0)   AS fee_outstanding,
       ps.placed_pct,
       ps.average_package_lpa,
       IFNULL(gr.open_grievances, 0)   AS open_grievances,
       RANK() OVER (ORDER BY cg.avg_cgpa DESC)  AS cgpa_rank,
       RANK() OVER (ORDER BY ps.placed_pct DESC) AS placement_rank
  FROM department d
  LEFT JOIN (SELECT p.dept_code, COUNT(*) AS students
               FROM student s JOIN program p ON p.program_id = s.program_id
              WHERE s.status = 'ACTIVE' GROUP BY p.dept_code) st ON st.dept_code = d.dept_code
  LEFT JOIN (SELECT dept_code, COUNT(*) AS faculty
               FROM employee WHERE employee_type = 'TEACHING' AND status = 'ACTIVE'
              GROUP BY dept_code) fa ON fa.dept_code = d.dept_code
  LEFT JOIN (SELECT dept_code, COUNT(*) AS courses FROM course GROUP BY dept_code) co ON co.dept_code = d.dept_code
  LEFT JOIN (SELECT p.dept_code, ROUND(AVG(fn_calculate_cgpa(s.student_id)), 2) AS avg_cgpa
               FROM student s JOIN program p ON p.program_id = s.program_id
              WHERE s.status = 'ACTIVE' GROUP BY p.dept_code) cg ON cg.dept_code = d.dept_code
  LEFT JOIN (SELECT p.dept_code,
                    ROUND(100 * SUM(sa.status IN ('PRESENT','LATE')) / COUNT(*), 2) AS avg_attendance_pct
               FROM student_attendance sa
               JOIN student s  ON s.student_id = sa.student_id
               JOIN program p  ON p.program_id = s.program_id
              GROUP BY p.dept_code) att ON att.dept_code = d.dept_code
  LEFT JOIN (SELECT p.dept_code, SUM(fp.amount) AS fee_collected
               FROM fee_payment fp
               JOIN fee_invoice fi ON fi.invoice_id = fp.invoice_id
               JOIN student s      ON s.student_id = fi.student_id
               JOIN program p      ON p.program_id = s.program_id
              WHERE fp.status = 'SUCCESS' GROUP BY p.dept_code) fe ON fe.dept_code = d.dept_code
  LEFT JOIN (SELECT p.dept_code, SUM(fi.balance) AS fee_outstanding
               FROM fee_invoice fi
               JOIN student s ON s.student_id = fi.student_id
               JOIN program p ON p.program_id = s.program_id
              WHERE fi.status IN ('UNPAID','PARTIALLY_PAID') GROUP BY p.dept_code) fo ON fo.dept_code = d.dept_code
  LEFT JOIN vw_placement_statistics ps ON ps.dept_code = d.dept_code
  LEFT JOIN (SELECT COALESCE(p.dept_code, e.dept_code) AS dept_code, COUNT(*) AS open_grievances
               FROM grievance g
               JOIN app_user u      ON u.user_id = g.raised_by
               LEFT JOIN student s  ON s.student_id = u.student_id
               LEFT JOIN program p  ON p.program_id = s.program_id
               LEFT JOIN employee e ON e.employee_id = u.employee_id
              WHERE g.status IN ('OPEN','IN_PROGRESS','ESCALATED')
              GROUP BY COALESCE(p.dept_code, e.dept_code)) gr ON gr.dept_code = d.dept_code
 WHERE d.dept_type = 'ACADEMIC';
