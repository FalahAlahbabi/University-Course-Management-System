------------------------------------------------------------------------
-- SQL Script  (CREATE TABLES + sample data)


SET SERVEROUTPUT ON;

------------------------------------------------------------------------
-- Clean up any previous run

BEGIN
   FOR t IN (SELECT table_name FROM user_tables
             WHERE table_name IN
                ('EXAM_RESULTS','EXAMS','COURSE_GRADE','COURSE_INSTRUCTORS',
                 'COURSE_SECTIONS','COURSES','STUDENTS','CLASSROOMS',
                 'INSTRUCTORS','DEPARTMENTS'))
   LOOP
      EXECUTE IMMEDIATE 'DROP TABLE '||t.table_name||' CASCADE CONSTRAINTS';
   END LOOP;
END;
/

------------------------------------------------------------------------
-- DEPARTMENTS

CREATE TABLE Departments (
    DepartmentID    NUMBER(5)       PRIMARY KEY,
    DeptName        VARCHAR2(60)    NOT NULL UNIQUE,
    OfficeLocation  VARCHAR2(50),
    PhoneNumber     VARCHAR2(20),
    ChairID         NUMBER(5)           -- FK added after Instructors exist
);

------------------------------------------------------------------------
-- INSTRUCTORS

CREATE TABLE Instructors (
    InstructorID    NUMBER(5)       PRIMARY KEY,
    FirstName       VARCHAR2(30)    NOT NULL,
    LastName        VARCHAR2(30)    NOT NULL,
    Email           VARCHAR2(80)    UNIQUE,
    Phone           VARCHAR2(20),
    HireDate        DATE,
    DepartmentID    NUMBER(5)       NOT NULL,
    CONSTRAINT fk_inst_dept FOREIGN KEY (DepartmentID)
        REFERENCES Departments(DepartmentID)
);

-- Now that Instructors exists we can add the circular FK for Chair
ALTER TABLE Departments
    ADD CONSTRAINT fk_dept_chair FOREIGN KEY (ChairID)
        REFERENCES Instructors(InstructorID);

------------------------------------------------------------------------
-- STUDENTS

CREATE TABLE Students (
    StudentID       NUMBER(7)       PRIMARY KEY,
    FirstName       VARCHAR2(30)    NOT NULL,
    LastName        VARCHAR2(30)    NOT NULL,
    Email           VARCHAR2(80)    UNIQUE,
    DOB             DATE,
    Gender          CHAR(1)         CHECK (Gender IN ('M','F')),
    EnrollmentYear  NUMBER(4)       CHECK (EnrollmentYear BETWEEN 1950 AND 2100),
    MajorDeptID     NUMBER(5)       NOT NULL,
    AdvisorID       NUMBER(5),
    CONSTRAINT fk_stud_dept FOREIGN KEY (MajorDeptID)
        REFERENCES Departments(DepartmentID),
    CONSTRAINT fk_stud_adv  FOREIGN KEY (AdvisorID)
        REFERENCES Instructors(InstructorID)
);

------------------------------------------------------------------------
-- COURSES

CREATE TABLE Courses (
    CourseID        VARCHAR2(10)    PRIMARY KEY,
    Title           VARCHAR2(80)    NOT NULL,
    CreditHours     NUMBER(2)       CHECK (CreditHours BETWEEN 1 AND 6),
    DepartmentID    NUMBER(5)       NOT NULL,
    CONSTRAINT fk_course_dept FOREIGN KEY (DepartmentID)
        REFERENCES Departments(DepartmentID)
);

------------------------------------------------------------------------
-- CLASSROOMS

CREATE TABLE Classrooms (
    RoomID          NUMBER(5)       PRIMARY KEY,
    BuildingName    VARCHAR2(40)    NOT NULL,
    RoomNumber      VARCHAR2(10)    NOT NULL,
    Capacity        NUMBER(4)       CHECK (Capacity > 0)
);

------------------------------------------------------------------------
-- 6.  COURSE_SECTIONS

CREATE TABLE Course_Sections (
    SectionID       NUMBER(7)       PRIMARY KEY,
    CourseID        VARCHAR2(10)    NOT NULL,
    InstructorID    NUMBER(5)       NOT NULL,
    RoomID          NUMBER(5)       NOT NULL,
    Semester        VARCHAR2(10)    CHECK (Semester IN ('Fall','Spring','Summer')),
    SectYear        NUMBER(4),
    SectionNumber   NUMBER(2),
    MeetingDay      VARCHAR2(10)    CHECK (MeetingDay IN
                                     ('Sunday','Monday','Tuesday','Wednesday',
                                      'Thursday','Friday','Saturday')),
    StartTime       VARCHAR2(5),    -- 'HH24:MI'
    EndTime         VARCHAR2(5),
    CONSTRAINT fk_sec_course FOREIGN KEY (CourseID)
        REFERENCES Courses(CourseID),
    CONSTRAINT fk_sec_inst   FOREIGN KEY (InstructorID)
        REFERENCES Instructors(InstructorID),
    CONSTRAINT fk_sec_room   FOREIGN KEY (RoomID)
        REFERENCES Classrooms(RoomID)
);

------------------------------------------------------------------------
-- COURSE_INSTRUCTORS  (resolves the M:N "team-teaches" relationship)

CREATE TABLE Course_Instructors (
    CourseID        VARCHAR2(10),
    InstructorID    NUMBER(5),
    CONSTRAINT pk_ci          PRIMARY KEY (CourseID, InstructorID),
    CONSTRAINT fk_ci_course   FOREIGN KEY (CourseID)
        REFERENCES Courses(CourseID),
    CONSTRAINT fk_ci_inst     FOREIGN KEY (InstructorID)
        REFERENCES Instructors(InstructorID)
);

------------------------------------------------------------------------
-- COURSE_GRADE

CREATE TABLE Course_Grade (
    StudentID       NUMBER(7),
    SectionID       NUMBER(7),
    Status          VARCHAR2(10)    CHECK (Status IN ('Enrolled','Completed','Dropped')),
    FinalGrade      VARCHAR2(2)     CHECK (FinalGrade IN
                                     ('A+','A','A-','B+','B','B-',
                                      'C+','C','C-','D+','D','F','W')),
    CONSTRAINT pk_cg        PRIMARY KEY (StudentID, SectionID),
    CONSTRAINT fk_cg_stud   FOREIGN KEY (StudentID)
        REFERENCES Students(StudentID),
    CONSTRAINT fk_cg_sect   FOREIGN KEY (SectionID)
        REFERENCES Course_Sections(SectionID)
);

------------------------------------------------------------------------
-- EXAMS

CREATE TABLE Exams (
    ExamID          NUMBER(7)       PRIMARY KEY,
    SectionID       NUMBER(7)       NOT NULL,
    ExamType        VARCHAR2(15)    CHECK (ExamType IN ('Midterm','Final','Quiz')),
    ExamDate        DATE,
    MaxMarks        NUMBER(5,2)     CHECK (MaxMarks > 0),
    CONSTRAINT fk_exam_sect FOREIGN KEY (SectionID)
        REFERENCES Course_Sections(SectionID)
);

------------------------------------------------------------------------
-- EXAM_RESULTS   (M:N between Students and Exams)

CREATE TABLE Exam_Results (
    StudentID       NUMBER(7),
    ExamID          NUMBER(7),
    MarksObtained   NUMBER(5,2)     CHECK (MarksObtained >= 0),
    CONSTRAINT pk_er      PRIMARY KEY (StudentID, ExamID),
    CONSTRAINT fk_er_stud FOREIGN KEY (StudentID)
        REFERENCES Students(StudentID),
    CONSTRAINT fk_er_exam FOREIGN KEY (ExamID)
        REFERENCES Exams(ExamID)
);

------------------------------------------------------------------------
--  SAMPLE DATA  (at least 5 rows per table)


------------------ Departments (chair filled later) -------------------
INSERT INTO Departments VALUES (10,'Computer Science & Engineering','CCE-201','+974-4403-4000',NULL);
INSERT INTO Departments VALUES (20,'Electrical Engineering',         'CCE-301','+974-4403-4100',NULL);
INSERT INTO Departments VALUES (30,'Mathematics',                    'CAS-110','+974-4403-4200',NULL);
INSERT INTO Departments VALUES (40,'Physics',                        'CAS-220','+974-4403-4300',NULL);
INSERT INTO Departments VALUES (50,'Business Administration',        'CBE-105','+974-4403-4400',NULL);

------------------ Instructors ----------------------------------------
INSERT INTO Instructors VALUES (101,'John','Smith',     'jsmith@univ.edu', '+974-5555-1001',TO_DATE('2015-09-01','YYYY-MM-DD'),10);
INSERT INTO Instructors VALUES (102,'Maria','Garcia',   'mgarcia@univ.edu','+974-5555-1002',TO_DATE('2018-02-15','YYYY-MM-DD'),10);
INSERT INTO Instructors VALUES (103,'Ahmed','Ali',      'aali@univ.edu',   '+974-5555-1003',TO_DATE('2019-08-20','YYYY-MM-DD'),10);
INSERT INTO Instructors VALUES (104,'Sarah','Johnson',  'sjohn@univ.edu',  '+974-5555-1004',TO_DATE('2016-01-10','YYYY-MM-DD'),20);
INSERT INTO Instructors VALUES (105,'Omar','Hassan',    'ohassan@univ.edu','+974-5555-1005',TO_DATE('2017-09-01','YYYY-MM-DD'),20);
INSERT INTO Instructors VALUES (106,'Fatima','Khalifa', 'fkhalifa@univ.edu','+974-5555-1006',TO_DATE('2014-09-01','YYYY-MM-DD'),30);
INSERT INTO Instructors VALUES (107,'Robert','Brown',   'rbrown@univ.edu', '+974-5555-1007',TO_DATE('2020-09-01','YYYY-MM-DD'),30);
INSERT INTO Instructors VALUES (108,'Nora','Al-Ansari', 'nansari@univ.edu','+974-5555-1008',TO_DATE('2013-09-01','YYYY-MM-DD'),40);
INSERT INTO Instructors VALUES (109,'David','Wilson',   'dwilson@univ.edu','+974-5555-1009',TO_DATE('2021-02-01','YYYY-MM-DD'),40);
INSERT INTO Instructors VALUES (110,'Linda','White',    'lwhite@univ.edu', '+974-5555-1010',TO_DATE('2012-09-01','YYYY-MM-DD'),50);

------------------ Assign department chairs ---------------------------

UPDATE Departments SET ChairID = 101 WHERE DepartmentID = 10;
UPDATE Departments SET ChairID = 104 WHERE DepartmentID = 20;
UPDATE Departments SET ChairID = 106 WHERE DepartmentID = 30;
UPDATE Departments SET ChairID = 108 WHERE DepartmentID = 40;
UPDATE Departments SET ChairID = 110 WHERE DepartmentID = 50;

------------------ Classrooms -----------------------------------------
INSERT INTO Classrooms VALUES (201,'Engineering Building','101',40);
INSERT INTO Classrooms VALUES (202,'Engineering Building','102',30);
INSERT INTO Classrooms VALUES (203,'Engineering Building','201',50);
INSERT INTO Classrooms VALUES (204,'Science Building',    '101',60);
INSERT INTO Classrooms VALUES (205,'Business Building',   '201',45);

------------------ Students -------------------------------------------
INSERT INTO Students VALUES (1001,'Ali',   'Khalid',    'ali.k@stu.univ.edu',   TO_DATE('2003-05-12','YYYY-MM-DD'),'M',2021,10,101);
INSERT INTO Students VALUES (1002,'Fatima','Zahra',     'fatima.z@stu.univ.edu',TO_DATE('2003-07-19','YYYY-MM-DD'),'F',2021,10,102);
INSERT INTO Students VALUES (1003,'Ahmed', 'Saleh',     'ahmed.s@stu.univ.edu', TO_DATE('2002-11-03','YYYY-MM-DD'),'M',2020,20,104);
INSERT INTO Students VALUES (1004,'Layla', 'Ibrahim',   'layla.i@stu.univ.edu', TO_DATE('2004-01-25','YYYY-MM-DD'),'F',2022,30,106);
INSERT INTO Students VALUES (1005,'Omar',  'Yousef',    'omar.y@stu.univ.edu',  TO_DATE('2003-09-09','YYYY-MM-DD'),'M',2021,40,108);
INSERT INTO Students VALUES (1006,'Aisha', 'Mohammed',  'aisha.m@stu.univ.edu', TO_DATE('2003-03-17','YYYY-MM-DD'),'F',2021,50,110);
INSERT INTO Students VALUES (1007,'Khalid','Rashid',    'khalid.r@stu.univ.edu',TO_DATE('2002-12-30','YYYY-MM-DD'),'M',2020,10,103);
INSERT INTO Students VALUES (1008,'Maryam','Al-Kaabi',  'maryam.k@stu.univ.edu',TO_DATE('2004-06-22','YYYY-MM-DD'),'F',2022,10,101);

------------------ Courses --------------------------------------------
INSERT INTO Courses VALUES ('CSE101','Introduction to Programming',3,10);
INSERT INTO Courses VALUES ('CSE201','Data Structures',            3,10);
INSERT INTO Courses VALUES ('CSE301','Database Systems',           3,10);
INSERT INTO Courses VALUES ('EE101', 'Circuit Analysis',           3,20);
INSERT INTO Courses VALUES ('MATH201','Calculus II',               4,30);
INSERT INTO Courses VALUES ('PHYS101','General Physics I',         4,40);
INSERT INTO Courses VALUES ('BUSI101','Introduction to Business',  3,50);

------------------ Course_Sections ------------------------------------
INSERT INTO Course_Sections VALUES (5001,'CSE101', 101,201,'Fall',2025,1,'Sunday',   '08:00','09:30');
INSERT INTO Course_Sections VALUES (5002,'CSE201', 102,202,'Fall',2025,1,'Monday',   '10:00','11:30');
INSERT INTO Course_Sections VALUES (5003,'CSE301', 103,203,'Fall',2025,1,'Tuesday',  '11:00','12:30');
INSERT INTO Course_Sections VALUES (5004,'EE101',  104,201,'Fall',2025,1,'Wednesday','09:00','10:30');
INSERT INTO Course_Sections VALUES (5005,'MATH201',106,204,'Fall',2025,1,'Thursday', '10:00','11:30');
INSERT INTO Course_Sections VALUES (5006,'PHYS101',108,204,'Fall',2025,1,'Sunday',   '13:00','14:30');
INSERT INTO Course_Sections VALUES (5007,'BUSI101',110,205,'Fall',2025,1,'Monday',   '13:00','14:30');

------------------ Course_Instructors (team teaching) -----------------
INSERT INTO Course_Instructors VALUES ('CSE101', 101);
INSERT INTO Course_Instructors VALUES ('CSE101', 102);   
INSERT INTO Course_Instructors VALUES ('CSE201', 102);
INSERT INTO Course_Instructors VALUES ('CSE301', 103);
INSERT INTO Course_Instructors VALUES ('EE101',  104);
INSERT INTO Course_Instructors VALUES ('MATH201',106);
INSERT INTO Course_Instructors VALUES ('PHYS101',108);

------------------ Course_Grade (enrollment + grade) ------------------
INSERT INTO Course_Grade VALUES (1001,5001,'Completed','A');
INSERT INTO Course_Grade VALUES (1001,5002,'Completed','B');
INSERT INTO Course_Grade VALUES (1001,5005,'Completed','B+');
INSERT INTO Course_Grade VALUES (1002,5001,'Completed','A');
INSERT INTO Course_Grade VALUES (1002,5003,'Completed','B');
INSERT INTO Course_Grade VALUES (1003,5004,'Completed','C');
INSERT INTO Course_Grade VALUES (1004,5005,'Completed','A');
INSERT INTO Course_Grade VALUES (1005,5006,'Completed','B');
INSERT INTO Course_Grade VALUES (1007,5003,'Dropped',  'W');
INSERT INTO Course_Grade VALUES (1008,5001,'Enrolled', NULL);

------------------ Exams ----------------------------------------------
INSERT INTO Exams VALUES (9001,5001,'Midterm',TO_DATE('2025-10-15','YYYY-MM-DD'),30);
INSERT INTO Exams VALUES (9002,5001,'Final',  TO_DATE('2025-12-18','YYYY-MM-DD'),50);
INSERT INTO Exams VALUES (9003,5002,'Midterm',TO_DATE('2025-10-20','YYYY-MM-DD'),30);
INSERT INTO Exams VALUES (9004,5002,'Final',  TO_DATE('2025-12-20','YYYY-MM-DD'),50);
INSERT INTO Exams VALUES (9005,5003,'Midterm',TO_DATE('2025-10-22','YYYY-MM-DD'),30);
INSERT INTO Exams VALUES (9006,5003,'Quiz',   TO_DATE('2025-11-05','YYYY-MM-DD'),10);

------------------ Exam_Results ---------------------------------------
INSERT INTO Exam_Results VALUES (1001,9001,28);
INSERT INTO Exam_Results VALUES (1001,9002,45);
INSERT INTO Exam_Results VALUES (1001,9003,25);
INSERT INTO Exam_Results VALUES (1001,9004,42);
INSERT INTO Exam_Results VALUES (1002,9001,29);
INSERT INTO Exam_Results VALUES (1002,9002,47);
INSERT INTO Exam_Results VALUES (1002,9005,27);

COMMIT;

