------------------------------------------------------------------------
--  1.  Function  calculate_gpa
--  2.  Trigger   enforce_instructor_schedule_conflict
--  3.  Procedure generate_student_transcript
--  4.  Trigger   validate_department_chair


SET SERVEROUTPUT ON;

------------------------------------------------------------------------
-- 1.  FUNCTION:  calculate_gpa
--     Returns the cumulative GPA for a given student over all
--     Completed enrollments.  Returns 0 if none are completed.

CREATE OR REPLACE FUNCTION calculate_gpa (p_student_id IN NUMBER)
RETURN NUMBER
IS
    v_total_points  NUMBER := 0;
    v_total_credits NUMBER := 0;
    v_gpa           NUMBER := 0;
BEGIN
    FOR r IN (
        SELECT c.CreditHours  AS credits,
               cg.FinalGrade  AS grade
        FROM   Course_Grade    cg
               JOIN Course_Sections cs ON cg.SectionID = cs.SectionID
               JOIN Courses         c  ON cs.CourseID  = c.CourseID
        WHERE  cg.StudentID = p_student_id
          AND  cg.Status    = 'Completed'
          AND  cg.FinalGrade IS NOT NULL
    )
    LOOP
        v_total_credits := v_total_credits + r.credits;
        v_total_points  := v_total_points  + r.credits *
            CASE r.grade
                WHEN 'A+' THEN 4.0
                WHEN 'A'  THEN 4.0
                WHEN 'A-' THEN 3.7
                WHEN 'B+' THEN 3.3
                WHEN 'B'  THEN 3.0
                WHEN 'B-' THEN 2.7
                WHEN 'C+' THEN 2.3
                WHEN 'C'  THEN 2.0
                WHEN 'C-' THEN 1.7
                WHEN 'D+' THEN 1.3
                WHEN 'D'  THEN 1.0
                WHEN 'F'  THEN 0.0
                ELSE 0.0
            END;
    END LOOP;

    IF v_total_credits = 0 THEN
        RETURN 0;
    ELSE
        v_gpa := ROUND(v_total_points / v_total_credits, 2);
        RETURN v_gpa;
    END IF;
END calculate_gpa;
/

------------------------------------------------------------------------
-- 2.  TRIGGER:  enforce_instructor_schedule_conflict
--     Prevents an instructor from being assigned to two sections with
--     overlapping times in the same semester / year / day.

CREATE OR REPLACE TRIGGER enforce_instructor_schedule_conflict
BEFORE INSERT OR UPDATE ON Course_Sections
FOR EACH ROW
DECLARE
    v_conflicts NUMBER := 0;
BEGIN
    SELECT COUNT(*)
      INTO v_conflicts
      FROM Course_Sections cs
     WHERE cs.InstructorID = :NEW.InstructorID
       AND cs.Semester     = :NEW.Semester
       AND cs.SectYear     = :NEW.SectYear
       AND cs.MeetingDay   = :NEW.MeetingDay
       AND cs.SectionID   <> NVL(:NEW.SectionID, -1)
       AND (:NEW.StartTime < cs.EndTime
            AND :NEW.EndTime  > cs.StartTime);

    IF v_conflicts > 0 THEN
        RAISE_APPLICATION_ERROR(-20010,
            'Schedule conflict: instructor '||:NEW.InstructorID||
            ' already has a section at that day/time in '||
            :NEW.Semester||' '||:NEW.SectYear||'.');
    END IF;
END;
/

------------------------------------------------------------------------
-- 3.  PROCEDURE:  generate_student_transcript
--     Prints a formatted academic transcript for the given student
--     and appends the cumulative GPA using calculate_gpa().

CREATE OR REPLACE PROCEDURE generate_student_transcript (p_student_id IN NUMBER)
IS
    v_fullname  VARCHAR2(80);
    v_gpa       NUMBER;
    v_found     BOOLEAN := FALSE;

    CURSOR c_courses IS
        SELECT c.Title        AS title,
               c.CreditHours  AS credits,
               cs.Semester    AS sem,
               cs.SectYear    AS yr,
               cg.FinalGrade  AS grade
        FROM   Course_Grade    cg
               JOIN Course_Sections cs ON cg.SectionID = cs.SectionID
               JOIN Courses         c  ON cs.CourseID  = c.CourseID
        WHERE  cg.StudentID = p_student_id
          AND  cg.Status    = 'Completed'
        ORDER BY cs.SectYear, cs.Semester;
BEGIN
    -- Header
    SELECT FirstName || ' ' || LastName
      INTO v_fullname
      FROM Students
     WHERE StudentID = p_student_id;

    DBMS_OUTPUT.PUT_LINE('================================================================');
    DBMS_OUTPUT.PUT_LINE('                  STUDENT ACADEMIC TRANSCRIPT                    ');
    DBMS_OUTPUT.PUT_LINE('================================================================');
    DBMS_OUTPUT.PUT_LINE('Student ID    : ' || p_student_id);
    DBMS_OUTPUT.PUT_LINE('Student Name  : ' || v_fullname);
    DBMS_OUTPUT.PUT_LINE('----------------------------------------------------------------');
    DBMS_OUTPUT.PUT_LINE( RPAD('Course Title',35) || RPAD('Cr',4) ||
                          RPAD('Semester',10) || RPAD('Year',6) || 'Grade' );
    DBMS_OUTPUT.PUT_LINE('----------------------------------------------------------------');

    -- Course rows
    FOR r IN c_courses LOOP
        v_found := TRUE;
        DBMS_OUTPUT.PUT_LINE(
            RPAD(r.title, 35)        ||
            RPAD(TO_CHAR(r.credits),4)||
            RPAD(r.sem,10)           ||
            RPAD(TO_CHAR(r.yr),6)    ||
            r.grade );
    END LOOP;

    IF NOT v_found THEN
        DBMS_OUTPUT.PUT_LINE('   (No completed courses on record.)');
    END IF;

    -- Cumulative GPA
    v_gpa := calculate_gpa(p_student_id);
    DBMS_OUTPUT.PUT_LINE('----------------------------------------------------------------');
    DBMS_OUTPUT.PUT_LINE('Cumulative GPA: ' || TO_CHAR(v_gpa, '0.00'));
    DBMS_OUTPUT.PUT_LINE('================================================================');

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        DBMS_OUTPUT.PUT_LINE('Error: no student found with ID '||p_student_id);
END generate_student_transcript;
/

------------------------------------------------------------------------
-- 4.  TRIGGER:  validate_department_chair
--     Ensures the assigned department chair (ChairID on Departments)
--     is an instructor who already belongs to that department.

CREATE OR REPLACE TRIGGER validate_department_chair
BEFORE INSERT OR UPDATE ON Departments
FOR EACH ROW
WHEN (NEW.ChairID IS NOT NULL)
DECLARE
    v_inst_dept NUMBER;
BEGIN
    SELECT DepartmentID
      INTO v_inst_dept
      FROM Instructors
     WHERE InstructorID = :NEW.ChairID;

    IF v_inst_dept <> :NEW.DepartmentID THEN
        RAISE_APPLICATION_ERROR(-20020,
            'Chair must be an instructor from the same department. '||
            'Instructor '||:NEW.ChairID||' belongs to dept '||v_inst_dept||
            ', but is being assigned to lead dept '||:NEW.DepartmentID||'.');
    END IF;

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RAISE_APPLICATION_ERROR(-20021,
            'Instructor '||:NEW.ChairID||' does not exist.');
END;
/

