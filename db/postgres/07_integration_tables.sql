-- PostgreSQL port of db/07_integration.sql (cross-module foreign keys). MySQL original is unchanged.
-- Needs tables from more than one module, so it runs after every *_tables.sql.
--   * app_user -> student / employee   (integration map row 5)

ALTER TABLE app_user
  ADD CONSTRAINT fk_app_user_student  FOREIGN KEY (student_id)  REFERENCES student (student_id),
  ADD CONSTRAINT fk_app_user_employee FOREIGN KEY (employee_id) REFERENCES employee (employee_id);
