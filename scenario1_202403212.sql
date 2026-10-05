-- ============================================================
-- SCENARIO 1: Online Course Registration
-- File Name: scenario1_[StudentNumber].sql
-- ============================================================

-- Step 1: Create Tables and Insert Initial Data
CREATE TABLE IF NOT EXISTS courses (
    course_id SERIAL PRIMARY KEY,
    course_code VARCHAR(20) NOT NULL,
    available_seats INT NOT NULL CHECK (available_seats >= 0)
);

CREATE TABLE IF NOT EXISTS enrollments (
    enrollment_id SERIAL PRIMARY KEY,
    course_id INT REFERENCES courses(course_id),
    student_name VARCHAR(100) NOT NULL,
    seats_enrolled INT NOT NULL CHECK (seats_enrolled > 0),
    status VARCHAR(20) NOT NULL CHECK (status IN ('ENROLLED', 'DROPPED'))
);

TRUNCATE TABLE enrollments, courses RESTART IDENTITY CASCADE;

INSERT INTO courses (course_code, available_seats) VALUES 
('CS101', 15),
('MATH201', 2),
('ENG102', 0);


-- Step 2: Conditional Logic (IF/ELSIF/ELSE)
DO $$
DECLARE
    v_seats INT;
BEGIN
    SELECT available_seats INTO v_seats 
    FROM courses WHERE course_id = 2;

    IF v_seats = 0 THEN
        RAISE NOTICE 'Course is completely full';
    ELSIF v_seats <= 2 THEN
        RAISE NOTICE 'Course is almost full: % seats left', v_seats;
    ELSE
        RAISE NOTICE 'Course has open seats: % available', v_seats;
    END IF;
END $$;


-- Step 3: Loops (WHILE and FOR)
DO $$
DECLARE
    v_step INT := 1;
BEGIN
    WHILE v_step <= 3 LOOP
        RAISE NOTICE 'Prerequisite verification step #%', v_step;
        v_step := v_step + 1;
    END LOOP;

    FOR v_check IN 1..3 LOOP
        RAISE NOTICE 'Checking roster clearance #%', v_check;
    END LOOP;
END $$;


-- Step 4: Procedure to Enroll Student
CREATE OR REPLACE PROCEDURE enroll_student(
    p_course_id INT,
    p_student_name VARCHAR,
    p_seats INT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_available INT;
BEGIN
    IF p_seats <= 0 THEN
        RAISE EXCEPTION 'Seats requested must be positive' USING ERRCODE = '22023';
    END IF;

    SELECT available_seats INTO v_available 
    FROM courses WHERE course_id = p_course_id FOR UPDATE;

    IF NOT FOUND THEN
        RAISE NOTICE 'Course ID % does not exist.', p_course_id;
        RETURN;
    ELSIF v_available < p_seats THEN
        RAISE NOTICE 'Cannot enroll; only % seats available.', v_available;
        RETURN;
    END IF;

    UPDATE courses 
    SET available_seats = available_seats - p_seats 
    WHERE course_id = p_course_id;

    INSERT INTO enrollments (course_id, student_name, seats_enrolled, status) 
    VALUES (p_course_id, p_student_name, p_seats, 'ENROLLED');
    
    RAISE NOTICE 'Successfully enrolled % in course %.', p_student_name, p_course_id;
END $$;


-- Step 5: Test Enroll Student Procedure
CALL enroll_student(1, 'John Doe', 1);
CALL enroll_student(2, 'Jane Smith', 2);
CALL enroll_student(3, 'Mark Lee', 1); -- Full capacity test


-- Step 6: Procedure to Drop Course
CREATE OR REPLACE PROCEDURE drop_course(p_enrollment_id INT)
LANGUAGE plpgsql
AS $$
DECLARE
    v_course_id INT;
    v_qty INT;
    v_status VARCHAR;
BEGIN
    SELECT course_id, seats_enrolled, status 
    INTO v_course_id, v_qty, v_status 
    FROM enrollments WHERE enrollment_id = p_enrollment_id FOR UPDATE;

    IF NOT FOUND THEN
        RAISE NOTICE 'Enrollment record % not found.', p_enrollment_id;
        RETURN;
    ELSIF v_status = 'DROPPED' THEN
        RAISE NOTICE 'Enrollment % is already dropped.', p_enrollment_id;
        RETURN;
    END IF;

    UPDATE enrollments SET status = 'DROPPED' WHERE enrollment_id = p_enrollment_id;
    UPDATE courses SET available_seats = available_seats + v_qty WHERE course_id = v_course_id;
    
    RAISE NOTICE 'Enrollment % dropped; seat restored.', p_enrollment_id;
END $$;

CALL drop_course(1);
CALL drop_course(1); -- Double drop check


-- Step 7: Cursor for Low Seat Courses
DO $$
DECLARE
    v_rec RECORD;
    c_low_seats CURSOR FOR 
        SELECT course_code, available_seats 
        FROM courses 
        WHERE available_seats <= 2;
BEGIN
    OPEN c_low_seats;
    LOOP
        FETCH c_low_seats INTO v_rec;
        EXIT WHEN NOT FOUND;
        RAISE NOTICE 'Low capacity course: "%" (% seats remaining)', v_rec.course_code, v_rec.available_seats;
    END LOOP;
    CLOSE c_low_seats;
END $$;


-- Step 8: Exception Handling Demonstration
DO $$
BEGIN
    CALL enroll_student(1, 'Sarah Connor', 0);
EXCEPTION
    WHEN invalid_parameter_value THEN
        RAISE NOTICE 'Handled Error: %', SQLERRM;
END $$;


-- Step 9: Final Status Verification
SELECT * FROM courses ORDER BY course_id;
SELECT * FROM enrollments ORDER BY enrollment_id;