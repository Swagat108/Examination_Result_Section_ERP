-- Emulates MySQL's  ON UPDATE CURRENT_TIMESTAMP  on every updated_at column.

CREATE OR REPLACE FUNCTION set_updated_at() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at := CURRENT_TIMESTAMP;
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_department_updated_at BEFORE UPDATE ON department
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_program_updated_at BEFORE UPDATE ON program
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_academic_year_updated_at BEFORE UPDATE ON academic_year
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_semester_updated_at BEFORE UPDATE ON semester
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_division_updated_at BEFORE UPDATE ON division
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_batch_updated_at BEFORE UPDATE ON batch
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_role_updated_at BEFORE UPDATE ON role
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_app_user_updated_at BEFORE UPDATE ON app_user
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_user_role_updated_at BEFORE UPDATE ON user_role
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_user_audit_log_updated_at BEFORE UPDATE ON user_audit_log
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_app_setting_updated_at BEFORE UPDATE ON app_setting
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_notice_updated_at BEFORE UPDATE ON notice
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_notice_target_updated_at BEFORE UPDATE ON notice_target
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_grievance_updated_at BEFORE UPDATE ON grievance
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_designation_updated_at BEFORE UPDATE ON designation
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_employee_updated_at BEFORE UPDATE ON employee
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_course_updated_at BEFORE UPDATE ON course
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_course_prerequisite_updated_at BEFORE UPDATE ON course_prerequisite
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_curriculum_updated_at BEFORE UPDATE ON curriculum
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_classroom_updated_at BEFORE UPDATE ON classroom
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_course_offering_updated_at BEFORE UPDATE ON course_offering
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_timetable_slot_updated_at BEFORE UPDATE ON timetable_slot
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_student_updated_at BEFORE UPDATE ON student
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_guardian_updated_at BEFORE UPDATE ON guardian
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_admission_updated_at BEFORE UPDATE ON admission
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_semester_registration_updated_at BEFORE UPDATE ON semester_registration
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_elective_selection_updated_at BEFORE UPDATE ON elective_selection
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_course_enrollment_updated_at BEFORE UPDATE ON course_enrollment
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_hostel_updated_at BEFORE UPDATE ON hostel
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_room_updated_at BEFORE UPDATE ON room
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_room_allocation_updated_at BEFORE UPDATE ON room_allocation
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_class_session_updated_at BEFORE UPDATE ON class_session
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_student_attendance_updated_at BEFORE UPDATE ON student_attendance
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_faculty_attendance_updated_at BEFORE UPDATE ON faculty_attendance
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_leave_type_updated_at BEFORE UPDATE ON leave_type
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_leave_application_updated_at BEFORE UPDATE ON leave_application
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_leave_balance_updated_at BEFORE UPDATE ON leave_balance
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_fee_structure_updated_at BEFORE UPDATE ON fee_structure
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_fee_audit_log_updated_at BEFORE UPDATE ON fee_audit_log
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_fee_invoice_updated_at BEFORE UPDATE ON fee_invoice
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_fee_payment_updated_at BEFORE UPDATE ON fee_payment
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_receipt_counter_updated_at BEFORE UPDATE ON receipt_counter
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_fee_receipt_updated_at BEFORE UPDATE ON fee_receipt
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_scholarship_updated_at BEFORE UPDATE ON scholarship
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_salary_structure_updated_at BEFORE UPDATE ON salary_structure
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_payroll_updated_at BEFORE UPDATE ON payroll
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_grade_scale_updated_at BEFORE UPDATE ON grade_scale
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_exam_updated_at BEFORE UPDATE ON exam
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_exam_schedule_updated_at BEFORE UPDATE ON exam_schedule
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_exam_registration_updated_at BEFORE UPDATE ON exam_registration
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_hall_ticket_updated_at BEFORE UPDATE ON hall_ticket
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_marks_updated_at BEFORE UPDATE ON marks
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_result_updated_at BEFORE UPDATE ON result
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_company_updated_at BEFORE UPDATE ON company
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_placement_drive_updated_at BEFORE UPDATE ON placement_drive
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_drive_eligible_branch_updated_at BEFORE UPDATE ON drive_eligible_branch
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_drive_application_updated_at BEFORE UPDATE ON drive_application
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_interview_round_updated_at BEFORE UPDATE ON interview_round
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_round_result_updated_at BEFORE UPDATE ON round_result
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_offer_updated_at BEFORE UPDATE ON offer
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
