-- =====================================================================
-- seed/sample/07_admin_sample.sql   |  G1 SAMPLE notices and grievances
-- The 10-day-old OPEN grievance is deliberately left un-escalated:
--   CALL sp_escalate_overdue_grievances();   -- demo step 10 turns it into ESCALATED
-- =====================================================================
SET NAMES utf8mb4;

SET @admin   = (SELECT user_id FROM app_user WHERE username = 'admin');
SET @student = (SELECT user_id FROM app_user WHERE username = 'student.demo');
SET @faculty = (SELECT user_id FROM app_user WHERE username = 'faculty.demo');

CALL sp_publish_notice('Welcome to Semester V, 2026-27',
                       'Classes for TY E&TC (divisions TY V - TY VIII) are in progress. Elective, honors and MDM allocations follow the final roll call. Check your timetable on the portal.',
                       'STUDENT', 'ETC', @admin, @n1);
CALL sp_publish_notice('Semester V examination registration is open',
                       'Registration for EX-2026-S5-01 closes on 10 Nov 2026. Students with attendance below 75 % in a course cannot register for that course.',
                       'STUDENT', NULL, @admin, @n2);
CALL sp_publish_notice('Staff meeting - timetable review',
                       'All faculty are requested to attend the timetable review meeting on Friday at 4 pm.',
                       'FACULTY', NULL, @admin, @n3);

INSERT INTO grievance (raised_by, category, subject, description, status, created_at) VALUES
  (@student, 'FEES',   'Receipt not generated',   'Paid the library fee but cannot find the receipt in the portal.', 'OPEN',        NOW() - INTERVAL 10 DAY),
  (@student, 'HOSTEL', 'Hostel room request',     'Requesting a hostel room allotment for this semester.',           'IN_PROGRESS', NOW() - INTERVAL 3 DAY),
  (@faculty, 'ADMINISTRATION', 'Projector in LH-302', 'Projector in LH-302 is not working.',                         'OPEN',        NOW() - INTERVAL 1 DAY);

INSERT INTO grievance (raised_by, category, subject, description, status, created_at, resolved_at, resolution_remarks)
VALUES (@student, 'ACADEMIC', 'Wrong division in portal', 'Division shown incorrectly.', 'RESOLVED',
        NOW() - INTERVAL 20 DAY, NOW() - INTERVAL 17 DAY, 'Corrected by the academic section.');
