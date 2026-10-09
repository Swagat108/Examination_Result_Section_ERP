-- =====================================================================
-- seed/07_users_seed.sql   |  G1 demo logins, one per role (bcrypt cost 10)
-- DEV ONLY - passwords are listed in the README. Change/remove before any real deployment.
-- student.demo is linked to the student with enrollment no F24ET003 (2024ETC0003).
-- =====================================================================
SET NAMES utf8mb4;

CALL sp_create_user_with_role('admin', 'admin@erp.local', '$2b$10$hhb7rsSQ.qUIAlhkMFlAHetfnVTHrsk3wyRXqS0x72j3Di7Qf07Sm', 'ADMIN', NULL, @uid);
CALL sp_create_user_with_role('faculty.demo', 'faculty.demo@erp.local', '$2b$10$sKsfBcHj/DagzLk/.DA87eUirBkWICDqUdcUCGIevuQ0aPacO7b.6', 'FACULTY', 'EMP0101', @uid);
CALL sp_create_user_with_role('accountant.demo', 'accountant.demo@erp.local', '$2b$10$7pMKSxWztqAQc1xE1gZkceFOTLFgwpeSP2ZRtAt1r3r9ZnrfNBCVy', 'ACCOUNTANT', 'EMP0201', @uid);
CALL sp_create_user_with_role('placement.demo', 'placement.demo@erp.local', '$2b$10$BqAlJf0o/.bTe0NLbt/Z/uO8115UCWV9.PxG2N4bkQJN8i2K2lTQS', 'PLACEMENT_OFFICER', 'EMP0202', @uid);
CALL sp_create_user_with_role('student.demo', 'student.demo@erp.local', '$2b$10$X8WH.UGrclOCRdFSYbKtrOFQMqmvrcuCeiujwBe5C5K8dCd3AFN3q', 'STUDENT', '2024ETC0003', @uid);
