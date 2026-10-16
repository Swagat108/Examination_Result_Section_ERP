-- PostgreSQL port of db/seed/sample/07_admin_sample.sql  |  G1 SAMPLE notices and grievances
-- The 10-day-old OPEN grievance is deliberately left un-escalated:
--   SELECT sp_escalate_overdue_grievances();   -- demo step 10 turns it into ESCALATED
SELECT set_config('seed.admin',   (SELECT user_id FROM app_user WHERE username = 'admin')::TEXT, false);
SELECT set_config('seed.student', (SELECT user_id FROM app_user WHERE username = 'student.demo')::TEXT, false);
SELECT set_config('seed.faculty', (SELECT user_id FROM app_user WHERE username = 'faculty.demo')::TEXT, false);

SELECT sp_publish_notice('Welcome to Semester V, 2026-27',
                         'Classes for TY E&TC (divisions TY V - TY VIII) are in progress. Elective, honors and MDM allocations follow the final roll call. Check your timetable on the portal.',
                         'STUDENT', 'ETC', current_setting('seed.admin')::INTEGER);
SELECT sp_publish_notice('Semester V examination registration is open',
                         'Registration for EX-2026-S5-01 closes on 10 Nov 2026. Students with attendance below 75 % in a course cannot register for that course.',
                         'STUDENT', NULL, current_setting('seed.admin')::INTEGER);
SELECT sp_publish_notice('Staff meeting - timetable review',
                         'All faculty are requested to attend the timetable review meeting on Friday at 4 pm.',
                         'FACULTY', NULL, current_setting('seed.admin')::INTEGER);

INSERT INTO grievance (raised_by, category, subject, description, status, created_at) VALUES
  (current_setting('seed.student')::INTEGER, 'FEES',   'Receipt not generated',   'Paid the library fee but cannot find the receipt in the portal.', 'OPEN',        NOW() - INTERVAL '10 days'),
  (current_setting('seed.student')::INTEGER, 'HOSTEL', 'Hostel room request',     'Requesting a hostel room allotment for this semester.',           'IN_PROGRESS', NOW() - INTERVAL '3 days'),
  (current_setting('seed.faculty')::INTEGER, 'ADMINISTRATION', 'Projector in LH-302', 'Projector in LH-302 is not working.',                         'OPEN',        NOW() - INTERVAL '1 day');

INSERT INTO grievance (raised_by, category, subject, description, status, created_at, resolved_at, resolution_remarks)
VALUES (current_setting('seed.student')::INTEGER, 'ACADEMIC', 'Wrong division in portal', 'Division shown incorrectly.', 'RESOLVED',
        NOW() - INTERVAL '20 days', NOW() - INTERVAL '17 days', 'Corrected by the academic section.');
