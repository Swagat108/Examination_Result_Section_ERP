-- =====================================================================
-- seed/01_academics_seed.sql   |  G3 data
-- SAMPLE DATA: the 40 faculty / 3 staff, classrooms and the core syllabus
-- are invented placeholders. The elective, honors and MDM courses are the
-- real ones from the Sem-V roll-call PDF (CC, DIVP, MI, CACD, MECHX, SDR,
-- VLSI-DT, IoT, BCT, MDM Maths / Finance). Replace the placeholders with
-- the real faculty list and syllabus when available.
-- =====================================================================
SET NAMES utf8mb4;

INSERT INTO designation (designation_name, rank_order) VALUES
  ('Professor',                    1),
  ('Associate Professor',          2),
  ('Assistant Professor',          3),
  ('Administrative Officer',       4),
  ('Training & Placement Officer', 5),
  ('Accountant',                   6);

-- ---------------------------------------------------------------------
-- Employees: 20 ETC + 10 CMP + 10 ITX faculty, 3 non-teaching staff
-- ---------------------------------------------------------------------
INSERT INTO employee (employee_id, full_name, email, dept_code, designation_id, employee_type, qualification, joining_date)
SELECT e.employee_id, e.full_name, e.email, e.dept_code, d.designation_id, e.employee_type, e.qualification, e.joining_date
  FROM (
    SELECT 'EMP0101' AS employee_id, 'Meera Kulkarni'   AS full_name, 'meera.kulkarni@erp.local'   AS email, 'ETC' AS dept_code, 'Professor'           AS designation, 'TEACHING' AS employee_type, 'Ph.D.'   AS qualification, '2008-07-01' AS joining_date
    UNION ALL SELECT 'EMP0102', 'Rajesh Patwardhan', 'rajesh.patwardhan@erp.local', 'ETC', 'Professor',           'TEACHING', 'Ph.D.',   '2009-06-15'
    UNION ALL SELECT 'EMP0103', 'Sunita Deshmukh',   'sunita.deshmukh@erp.local',   'ETC', 'Associate Professor', 'TEACHING', 'Ph.D.',   '2011-07-18'
    UNION ALL SELECT 'EMP0104', 'Anil Joshi',        'anil.joshi@erp.local',        'ETC', 'Associate Professor', 'TEACHING', 'Ph.D.',   '2012-08-01'
    UNION ALL SELECT 'EMP0105', 'Kavita Bhosale',    'kavita.bhosale@erp.local',    'ETC', 'Assistant Professor', 'TEACHING', 'M.Tech.', '2014-07-14'
    UNION ALL SELECT 'EMP0106', 'Vikram Phadke',     'vikram.phadke@erp.local',     'ETC', 'Assistant Professor', 'TEACHING', 'M.Tech.', '2015-06-22'
    UNION ALL SELECT 'EMP0107', 'Smita Gokhale',     'smita.gokhale@erp.local',     'ETC', 'Assistant Professor', 'TEACHING', 'M.Tech.', '2015-07-20'
    UNION ALL SELECT 'EMP0108', 'Prashant Kale',     'prashant.kale@erp.local',     'ETC', 'Assistant Professor', 'TEACHING', 'M.Tech.', '2016-07-11'
    UNION ALL SELECT 'EMP0109', 'Neha Apte',         'neha.apte@erp.local',         'ETC', 'Assistant Professor', 'TEACHING', 'M.Tech.', '2016-08-01'
    UNION ALL SELECT 'EMP0110', 'Sanjay More',       'sanjay.more@erp.local',       'ETC', 'Assistant Professor', 'TEACHING', 'M.Tech.', '2017-06-19'
    UNION ALL SELECT 'EMP0111', 'Anjali Naik',       'anjali.naik@erp.local',       'ETC', 'Assistant Professor', 'TEACHING', 'M.Tech.', '2017-07-24'
    UNION ALL SELECT 'EMP0112', 'Rohit Salunkhe',    'rohit.salunkhe@erp.local',    'ETC', 'Assistant Professor', 'TEACHING', 'M.Tech.', '2018-07-02'
    UNION ALL SELECT 'EMP0113', 'Pooja Mhatre',      'pooja.mhatre@erp.local',      'ETC', 'Assistant Professor', 'TEACHING', 'M.Tech.', '2018-08-06'
    UNION ALL SELECT 'EMP0114', 'Amit Ranade',       'amit.ranade@erp.local',       'ETC', 'Assistant Professor', 'TEACHING', 'M.Tech.', '2019-07-15'
    UNION ALL SELECT 'EMP0115', 'Shweta Kelkar',     'shweta.kelkar@erp.local',     'ETC', 'Assistant Professor', 'TEACHING', 'M.Tech.', '2019-07-29'
    UNION ALL SELECT 'EMP0116', 'Nitin Gaikwad',     'nitin.gaikwad@erp.local',     'ETC', 'Assistant Professor', 'TEACHING', 'M.Tech.', '2020-08-03'
    UNION ALL SELECT 'EMP0117', 'Deepa Sawant',      'deepa.sawant@erp.local',      'ETC', 'Assistant Professor', 'TEACHING', 'M.Tech.', '2021-07-12'
    UNION ALL SELECT 'EMP0118', 'Manoj Thakur',      'manoj.thakur@erp.local',      'ETC', 'Assistant Professor', 'TEACHING', 'M.Tech.', '2021-08-02'
    UNION ALL SELECT 'EMP0119', 'Ritu Bhandari',     'ritu.bhandari@erp.local',     'ETC', 'Assistant Professor', 'TEACHING', 'M.Tech.', '2022-07-18'
    UNION ALL SELECT 'EMP0120', 'Sachin Bhide',      'sachin.bhide@erp.local',      'ETC', 'Assistant Professor', 'TEACHING', 'M.Tech.', '2022-08-01'
    UNION ALL SELECT 'EMP0121', 'Alok Sharma',       'alok.sharma@erp.local',       'CMP', 'Professor',           'TEACHING', 'Ph.D.',   '2007-07-02'
    UNION ALL SELECT 'EMP0122', 'Priya Menon',       'priya.menon@erp.local',       'CMP', 'Associate Professor', 'TEACHING', 'Ph.D.',   '2011-06-27'
    UNION ALL SELECT 'EMP0123', 'Harish Nair',       'harish.nair@erp.local',       'CMP', 'Assistant Professor', 'TEACHING', 'M.Tech.', '2013-07-08'
    UNION ALL SELECT 'EMP0124', 'Swati Desai',       'swati.desai@erp.local',       'CMP', 'Assistant Professor', 'TEACHING', 'M.Tech.', '2014-08-04'
    UNION ALL SELECT 'EMP0125', 'Tushar Jagtap',     'tushar.jagtap@erp.local',     'CMP', 'Assistant Professor', 'TEACHING', 'M.Tech.', '2016-07-18'
    UNION ALL SELECT 'EMP0126', 'Madhuri Lele',      'madhuri.lele@erp.local',      'CMP', 'Assistant Professor', 'TEACHING', 'M.Tech.', '2017-07-10'
    UNION ALL SELECT 'EMP0127', 'Gaurav Mishra',     'gaurav.mishra@erp.local',     'CMP', 'Assistant Professor', 'TEACHING', 'M.Tech.', '2018-06-25'
    UNION ALL SELECT 'EMP0128', 'Ila Banerjee',      'ila.banerjee@erp.local',      'CMP', 'Assistant Professor', 'TEACHING', 'M.Tech.', '2019-08-05'
    UNION ALL SELECT 'EMP0129', 'Yogesh Tambe',      'yogesh.tambe@erp.local',      'CMP', 'Assistant Professor', 'TEACHING', 'M.Tech.', '2020-07-13'
    UNION ALL SELECT 'EMP0130', 'Rashmi Iyer',       'rashmi.iyer@erp.local',       'CMP', 'Assistant Professor', 'TEACHING', 'M.Tech.', '2022-07-04'
    UNION ALL SELECT 'EMP0131', 'Suresh Rao',        'suresh.rao@erp.local',        'ITX', 'Professor',           'TEACHING', 'Ph.D.',   '2008-06-30'
    UNION ALL SELECT 'EMP0132', 'Lata Pillai',       'lata.pillai@erp.local',       'ITX', 'Associate Professor', 'TEACHING', 'Ph.D.',   '2012-07-16'
    UNION ALL SELECT 'EMP0133', 'Kunal Mehta',       'kunal.mehta@erp.local',       'ITX', 'Assistant Professor', 'TEACHING', 'M.Tech.', '2014-06-23'
    UNION ALL SELECT 'EMP0134', 'Bhavna Shah',       'bhavna.shah@erp.local',       'ITX', 'Assistant Professor', 'TEACHING', 'M.Tech.', '2015-08-03'
    UNION ALL SELECT 'EMP0135', 'Ajay Verma',        'ajay.verma@erp.local',        'ITX', 'Assistant Professor', 'TEACHING', 'M.Tech.', '2016-07-25'
    UNION ALL SELECT 'EMP0136', 'Nandini Rane',      'nandini.rane@erp.local',      'ITX', 'Assistant Professor', 'TEACHING', 'M.Tech.', '2017-08-07'
    UNION ALL SELECT 'EMP0137', 'Siddharth Dixit',   'siddharth.dixit@erp.local',   'ITX', 'Assistant Professor', 'TEACHING', 'M.Tech.', '2018-07-09'
    UNION ALL SELECT 'EMP0138', 'Pallavi Kamat',     'pallavi.kamat@erp.local',     'ITX', 'Assistant Professor', 'TEACHING', 'M.Tech.', '2019-07-22'
    UNION ALL SELECT 'EMP0139', 'Omkar Wagh',        'omkar.wagh@erp.local',        'ITX', 'Assistant Professor', 'TEACHING', 'M.Tech.', '2020-08-10'
    UNION ALL SELECT 'EMP0140', 'Jyoti Chavhan',     'jyoti.chavhan@erp.local',     'ITX', 'Assistant Professor', 'TEACHING', 'M.Tech.', '2022-07-25'
    UNION ALL SELECT 'EMP0201', 'Ramesh Patil',      'ramesh.patil@erp.local',      'ADM', 'Accountant',                   'NON_TEACHING', 'M.Com.', '2010-04-01'
    UNION ALL SELECT 'EMP0202', 'Kirti Joshi',       'kirti.joshi@erp.local',       'ADM', 'Training & Placement Officer', 'NON_TEACHING', 'MBA',    '2016-09-01'
    UNION ALL SELECT 'EMP0203', 'Vasant Kulkarni',   'vasant.kulkarni@erp.local',   'ADM', 'Administrative Officer',       'NON_TEACHING', 'MBA',    '2006-06-01'
  ) e
  JOIN designation d ON d.designation_name = e.designation;

UPDATE department SET hod_employee_id = 'EMP0101' WHERE dept_code = 'ETC';
UPDATE department SET hod_employee_id = 'EMP0121' WHERE dept_code = 'CMP';
UPDATE department SET hod_employee_id = 'EMP0131' WHERE dept_code = 'ITX';
UPDATE department SET hod_employee_id = 'EMP0203' WHERE dept_code = 'ADM';

-- ---------------------------------------------------------------------
-- Course catalogue  (code, title, credits, type, category, dept, L, T, P)
-- ---------------------------------------------------------------------
INSERT INTO course (course_code, course_title, credits, course_type, category, dept_code, lecture_hrs, tutorial_hrs, practical_hrs) VALUES
  -- ETC semester 4 (placeholders; completed in 2025-26 even term, used for the result history)
  ('ETC201', 'Analog Circuits',                               3, 'THEORY', 'CORE', 'ETC', 3, 0, 0),
  ('ETC202', 'Signals and Systems',                           3, 'THEORY', 'CORE', 'ETC', 3, 0, 0),
  ('ETC203', 'Analog Communication',                          3, 'THEORY', 'CORE', 'ETC', 3, 0, 0),
  ('ETC204', 'Microcontrollers',                              3, 'THEORY', 'CORE', 'ETC', 3, 0, 0),
  ('ETC205', 'Analog Circuits and Communication Laboratory',  2, 'LAB',    'CORE', 'ETC', 0, 0, 4),
  ('ETC206', 'Microcontroller Laboratory',                    1, 'LAB',    'CORE', 'ETC', 0, 0, 2),
  -- ETC semester 5 core (placeholders)
  ('ETC301', 'Digital Communication',                         3, 'THEORY', 'CORE', 'ETC', 3, 0, 0),
  ('ETC302', 'Control Systems',                               3, 'THEORY', 'CORE', 'ETC', 3, 0, 0),
  ('ETC303', 'Digital Signal Processing',                     3, 'THEORY', 'CORE', 'ETC', 3, 0, 0),
  ('ETC304', 'Electromagnetics and Antennas',                 3, 'THEORY', 'CORE', 'ETC', 3, 0, 0),
  ('ETC305', 'Communication and DSP Laboratory',              2, 'LAB',    'CORE', 'ETC', 0, 0, 4),
  -- ETC semester 5 Program Elective-1 (from the roll call)
  ('ETC351', 'Cloud Computing (CC)',                          3, 'THEORY', 'PROGRAM_ELECTIVE', 'ETC', 3, 0, 0),
  ('ETC352', 'Digital Image and Video Processing (DIVP)',     3, 'THEORY', 'PROGRAM_ELECTIVE', 'ETC', 3, 0, 0),
  ('ETC353', 'Microcontrollers and IoT (MI)',                 3, 'THEORY', 'PROGRAM_ELECTIVE', 'ETC', 3, 0, 0),
  ('ETC354', 'CMOS Analog Circuit Design (CACD)',             3, 'THEORY', 'PROGRAM_ELECTIVE', 'ETC', 3, 0, 0),
  ('ETC355', 'Mechatronics (MECHX)',                          3, 'THEORY', 'PROGRAM_ELECTIVE', 'ETC', 3, 0, 0),
  ('ETC356', 'Software Defined Radio (SDR)',                  3, 'THEORY', 'PROGRAM_ELECTIVE', 'ETC', 3, 0, 0),
  -- Honors and MDM tracks (from the roll call)
  ('HON301', 'Honors: VLSI Design Technology (VLSI-DT)',      4, 'THEORY', 'HONORS', 'ETC', 4, 0, 0),
  ('HON302', 'Honors: Internet of Things (IoT)',              4, 'THEORY', 'HONORS', 'ETC', 4, 0, 0),
  ('HON303', 'Honors: Block Chain Technology (BCT)',          4, 'THEORY', 'HONORS', 'ETC', 4, 0, 0),
  ('MDM301', 'Multidisciplinary Minor: Mathematics',          3, 'THEORY', 'MDM',    'ETC', 3, 0, 0),
  ('MDM302', 'Multidisciplinary Minor: Finance',              3, 'THEORY', 'MDM',    'ETC', 3, 0, 0),
  -- ETC semester 6 (placeholders)
  ('ETC311', 'Microwave Engineering',                         3, 'THEORY', 'CORE', 'ETC', 3, 0, 0),
  ('ETC312', 'Embedded Systems',                              3, 'THEORY', 'CORE', 'ETC', 3, 0, 0),
  ('ETC313', 'Wireless and Mobile Communication',             3, 'THEORY', 'CORE', 'ETC', 3, 0, 0),
  ('ETC314', 'Information Theory and Coding',                 3, 'THEORY', 'CORE', 'ETC', 3, 0, 0),
  ('ETC315', 'Microwave and Wireless Laboratory',             2, 'LAB',    'CORE', 'ETC', 0, 0, 4),
  ('ETC316', 'Mini Project',                                  2, 'PROJECT','CORE', 'ETC', 0, 0, 4),
  -- CMP semesters 5 and 6 (placeholders)
  ('CMP301', 'Database Management Systems',                   3, 'THEORY', 'CORE', 'CMP', 3, 0, 0),
  ('CMP302', 'Computer Networks',                             3, 'THEORY', 'CORE', 'CMP', 3, 0, 0),
  ('CMP303', 'Theory of Computation',                         3, 'THEORY', 'CORE', 'CMP', 3, 0, 0),
  ('CMP304', 'Software Engineering',                          3, 'THEORY', 'CORE', 'CMP', 3, 0, 0),
  ('CMP305', 'Database Management Systems Laboratory',        2, 'LAB',    'CORE', 'CMP', 0, 0, 4),
  ('CMP311', 'Compiler Design',                               3, 'THEORY', 'CORE', 'CMP', 3, 0, 0),
  ('CMP312', 'Machine Learning',                              3, 'THEORY', 'CORE', 'CMP', 3, 0, 0),
  ('CMP313', 'Information Security',                          3, 'THEORY', 'CORE', 'CMP', 3, 0, 0),
  ('CMP314', 'Distributed Systems',                           3, 'THEORY', 'CORE', 'CMP', 3, 0, 0),
  ('CMP315', 'Machine Learning Laboratory',                   2, 'LAB',    'CORE', 'CMP', 0, 0, 4),
  -- ITX semesters 5 and 6 (placeholders)
  ('ITX301', 'Data Science',                                  3, 'THEORY', 'CORE', 'ITX', 3, 0, 0),
  ('ITX302', 'Web Technologies',                              3, 'THEORY', 'CORE', 'ITX', 3, 0, 0),
  ('ITX303', 'Operating Systems',                             3, 'THEORY', 'CORE', 'ITX', 3, 0, 0),
  ('ITX304', 'Software Testing',                              3, 'THEORY', 'CORE', 'ITX', 3, 0, 0),
  ('ITX305', 'Web Technologies Laboratory',                   2, 'LAB',    'CORE', 'ITX', 0, 0, 4),
  ('ITX311', 'Cloud Computing',                               3, 'THEORY', 'CORE', 'ITX', 3, 0, 0),
  ('ITX312', 'Mobile Application Development',                3, 'THEORY', 'CORE', 'ITX', 3, 0, 0),
  ('ITX313', 'Cyber Security',                                3, 'THEORY', 'CORE', 'ITX', 3, 0, 0),
  ('ITX314', 'Big Data Analytics',                            3, 'THEORY', 'CORE', 'ITX', 3, 0, 0),
  ('ITX315', 'Mobile Application Development Laboratory',     2, 'LAB',    'CORE', 'ITX', 0, 0, 4);

INSERT INTO course_prerequisite (course_code, prereq_course_code) VALUES
  ('ETC301', 'ETC203'),   -- Digital Communication  <- Analog Communication
  ('ETC303', 'ETC202'),   -- DSP                    <- Signals and Systems
  ('ETC311', 'ETC304'),   -- Microwave Engineering  <- Electromagnetics and Antennas
  ('ETC312', 'ETC204'),   -- Embedded Systems       <- Microcontrollers
  ('ETC313', 'ETC301'),   -- Wireless & Mobile      <- Digital Communication
  ('CMP312', 'CMP301'),   -- Machine Learning       <- DBMS
  ('ITX314', 'ITX301');   -- Big Data Analytics     <- Data Science

-- Curriculum: program x semester number x course (elective_group only for choice courses)
INSERT INTO curriculum (program_id, sem_no, course_code, elective_group)
SELECT p.program_id, v.sem_no, v.course_code, v.elective_group
  FROM program p
  JOIN (
    SELECT 'BTECH-ETC' AS program_code, 4 AS sem_no, 'ETC201' AS course_code, NULL AS elective_group
    UNION ALL SELECT 'BTECH-ETC', 4, 'ETC202', NULL
    UNION ALL SELECT 'BTECH-ETC', 4, 'ETC203', NULL
    UNION ALL SELECT 'BTECH-ETC', 4, 'ETC204', NULL
    UNION ALL SELECT 'BTECH-ETC', 4, 'ETC205', NULL
    UNION ALL SELECT 'BTECH-ETC', 4, 'ETC206', NULL
    UNION ALL SELECT 'BTECH-ETC', 5, 'ETC301', NULL
    UNION ALL SELECT 'BTECH-ETC', 5, 'ETC302', NULL
    UNION ALL SELECT 'BTECH-ETC', 5, 'ETC303', NULL
    UNION ALL SELECT 'BTECH-ETC', 5, 'ETC304', NULL
    UNION ALL SELECT 'BTECH-ETC', 5, 'ETC305', NULL
    UNION ALL SELECT 'BTECH-ETC', 5, 'ETC351', 'PE-1'
    UNION ALL SELECT 'BTECH-ETC', 5, 'ETC352', 'PE-1'
    UNION ALL SELECT 'BTECH-ETC', 5, 'ETC353', 'PE-1'
    UNION ALL SELECT 'BTECH-ETC', 5, 'ETC354', 'PE-1'
    UNION ALL SELECT 'BTECH-ETC', 5, 'ETC355', 'PE-1'
    UNION ALL SELECT 'BTECH-ETC', 5, 'ETC356', 'PE-1'
    UNION ALL SELECT 'BTECH-ETC', 5, 'HON301', 'HONORS'
    UNION ALL SELECT 'BTECH-ETC', 5, 'HON302', 'HONORS'
    UNION ALL SELECT 'BTECH-ETC', 5, 'HON303', 'HONORS'
    UNION ALL SELECT 'BTECH-ETC', 5, 'MDM301', 'MDM'
    UNION ALL SELECT 'BTECH-ETC', 5, 'MDM302', 'MDM'
    UNION ALL SELECT 'BTECH-ETC', 6, 'ETC311', NULL
    UNION ALL SELECT 'BTECH-ETC', 6, 'ETC312', NULL
    UNION ALL SELECT 'BTECH-ETC', 6, 'ETC313', NULL
    UNION ALL SELECT 'BTECH-ETC', 6, 'ETC314', NULL
    UNION ALL SELECT 'BTECH-ETC', 6, 'ETC315', NULL
    UNION ALL SELECT 'BTECH-ETC', 6, 'ETC316', NULL
    UNION ALL SELECT 'BTECH-CMP', 5, 'CMP301', NULL
    UNION ALL SELECT 'BTECH-CMP', 5, 'CMP302', NULL
    UNION ALL SELECT 'BTECH-CMP', 5, 'CMP303', NULL
    UNION ALL SELECT 'BTECH-CMP', 5, 'CMP304', NULL
    UNION ALL SELECT 'BTECH-CMP', 5, 'CMP305', NULL
    UNION ALL SELECT 'BTECH-CMP', 6, 'CMP311', NULL
    UNION ALL SELECT 'BTECH-CMP', 6, 'CMP312', NULL
    UNION ALL SELECT 'BTECH-CMP', 6, 'CMP313', NULL
    UNION ALL SELECT 'BTECH-CMP', 6, 'CMP314', NULL
    UNION ALL SELECT 'BTECH-CMP', 6, 'CMP315', NULL
    UNION ALL SELECT 'BTECH-ITX', 5, 'ITX301', NULL
    UNION ALL SELECT 'BTECH-ITX', 5, 'ITX302', NULL
    UNION ALL SELECT 'BTECH-ITX', 5, 'ITX303', NULL
    UNION ALL SELECT 'BTECH-ITX', 5, 'ITX304', NULL
    UNION ALL SELECT 'BTECH-ITX', 5, 'ITX305', NULL
    UNION ALL SELECT 'BTECH-ITX', 6, 'ITX311', NULL
    UNION ALL SELECT 'BTECH-ITX', 6, 'ITX312', NULL
    UNION ALL SELECT 'BTECH-ITX', 6, 'ITX313', NULL
    UNION ALL SELECT 'BTECH-ITX', 6, 'ITX314', NULL
    UNION ALL SELECT 'BTECH-ITX', 6, 'ITX315', NULL
  ) v ON v.program_code = p.program_code;

-- Rooms: one lecture room per TY division, one room per elective, one lab per division
INSERT INTO classroom (classroom_code, building, capacity, room_type) VALUES
  ('LH-301', 'Main Building', 100, 'LECTURE'), ('LH-302', 'Main Building', 100, 'LECTURE'),
  ('LH-303', 'Main Building', 100, 'LECTURE'), ('LH-304', 'Main Building', 100, 'LECTURE'),
  ('LH-401', 'Main Building', 200, 'LECTURE'), ('LH-402', 'Main Building', 120, 'LECTURE'),
  ('LH-403', 'Main Building', 120, 'LECTURE'), ('LH-404', 'Main Building', 120, 'LECTURE'),
  ('LH-405', 'Main Building', 120, 'LECTURE'), ('LH-406', 'Main Building', 120, 'LECTURE'),
  ('LH-407', 'Main Building',  80, 'LECTURE'), ('LH-408', 'Main Building',  80, 'LECTURE'),
  ('LH-409', 'Main Building',  80, 'LECTURE'), ('LH-410', 'Main Building',  80, 'LECTURE'),
  ('LH-411', 'Main Building',  80, 'LECTURE'),
  ('LAB-E1', 'Electronics Wing', 25, 'LAB'), ('LAB-E2', 'Electronics Wing', 25, 'LAB'),
  ('LAB-E3', 'Electronics Wing', 25, 'LAB'), ('LAB-E4', 'Electronics Wing', 25, 'LAB');

-- ---------------------------------------------------------------------
-- Offerings via the stored procedure
--   * 2025-26 even term, semester 4 only -> the history that the result seed is built on
--   * 2026-27 odd term (active)          -> semester 5 of every program
-- ---------------------------------------------------------------------
SET @sem_prev = (SELECT s.semester_id FROM semester s JOIN academic_year ay ON ay.academic_year_id = s.academic_year_id
                  WHERE ay.label = '2025-26' AND s.term = 'EVEN');
SET @sem_cur  = fn_current_semester();
CALL sp_generate_course_offerings(@sem_prev, 4);
CALL sp_generate_course_offerings(@sem_cur, NULL);
