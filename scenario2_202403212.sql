-- ============================================================
-- SCENARIO 2: Computer Laboratory Reservations
-- File Name: scenario2_[StudentNumber].sql
-- ============================================================

-- Step 1: Create Tables and Insert Initial Data
CREATE TABLE IF NOT EXISTS lab_sessions (
    session_id SERIAL PRIMARY KEY,
    course_name VARCHAR(100) NOT NULL,
    available_workstations INT NOT NULL CHECK (available_workstations >= 0)
);

CREATE TABLE IF NOT EXISTS reservations (
    reservation_id SERIAL PRIMARY KEY,
    session_id INT REFERENCES lab_sessions(session_id),
    lecturer_name VARCHAR(100) NOT NULL,
    workstations_reserved INT NOT NULL CHECK (workstations_reserved > 0),
    status VARCHAR(20) NOT NULL CHECK (status IN ('RESERVED', 'CANCELLED'))
);

TRUNCATE TABLE reservations, lab_sessions RESTART IDENTITY CASCADE;

INSERT INTO lab_sessions (course_name, available_workstations) VALUES 
('ICT371 Advanced Databases', 30),
('ICT311 Software Engineering', 2),
('ICT211 Computer Networks', 0);

-- Step 2: Conditional Logic (IF/ELSIF/ELSE)
DO $$
DECLARE
    v_workstations INT;
BEGIN
    SELECT available_workstations INTO v_workstations 
    FROM lab_sessions WHERE session_id = 2;

    IF v_workstations = 0 THEN
        RAISE NOTICE 'Lab session is full';
    ELSIF v_workstations <= 5 THEN
        RAISE NOTICE 'Lab session is nearly full: % workstations left', v_workstations;
    ELSE
        RAISE NOTICE 'Lab session has enough workstations: % available', v_workstations;
    END IF;
END $$;

-- Step 3: Loops (WHILE and FOR)
DO $$
DECLARE
    v_reminder INT := 1;
BEGIN
    WHILE v_reminder <= 3 LOOP
        RAISE NOTICE 'Session preparation reminder #%', v_reminder;
        v_reminder := v_reminder + 1;
    END LOOP;

    FOR v_check IN 1..3 LOOP
        RAISE NOTICE 'Performing workstation check #%', v_check;
    END LOOP;
END $$;

-- Step 4: Procedure to Reserve Workstations
CREATE OR REPLACE PROCEDURE reserve_workstations(
    p_session_id INT,
    p_lecturer_name VARCHAR,
    p_workstations INT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_available INT;
BEGIN
    IF p_workstations <= 0 THEN
        RAISE EXCEPTION 'Workstations requested must be positive' USING ERRCODE = '22023';
    END IF;

    SELECT available_workstations INTO v_available 
    FROM lab_sessions WHERE session_id = p_session_id FOR UPDATE;

    IF NOT FOUND THEN
        RAISE NOTICE 'Lab session % does not exist.', p_session_id;
        RETURN;
    ELSIF v_available < p_workstations THEN
        RAISE NOTICE 'Cannot reserve % workstations; only % available.', p_workstations, v_available;
        RETURN;
    END IF;

    UPDATE lab_sessions 
    SET available_workstations = available_workstations - p_workstations 
    WHERE session_id = p_session_id;

    INSERT INTO reservations (session_id, lecturer_name, workstations_reserved, status) 
    VALUES (p_session_id, p_lecturer_name, p_workstations, 'RESERVED');
    
    RAISE NOTICE 'Successfully reserved % workstations for %.', p_workstations, p_lecturer_name;
END $$;

-- Step 5: Test Reserve Workstations Procedure
CALL reserve_workstations(1, 'Dr. Banda', 10);
CALL reserve_workstations(2, 'Prof. Phiri', 2);
CALL reserve_workstations(2, 'Dr. Mulenga', 15);

-- Step 6: Procedure to Cancel Reservation and Test
CREATE OR REPLACE PROCEDURE cancel_reservation(p_reservation_id INT)
LANGUAGE plpgsql
AS $$
DECLARE
    v_session_id INT;
    v_qty INT;
    v_status VARCHAR;
BEGIN
    SELECT session_id, workstations_reserved, status 
    INTO v_session_id, v_qty, v_status 
    FROM reservations WHERE reservation_id = p_reservation_id FOR UPDATE;

    IF NOT FOUND THEN
        RAISE NOTICE 'Reservation % not found.', p_reservation_id;
        RETURN;
    ELSIF v_status = 'CANCELLED' THEN
        RAISE NOTICE 'Reservation % is already cancelled.', p_reservation_id;
        RETURN;
    END IF;

    UPDATE reservations SET status = 'CANCELLED' WHERE reservation_id = p_reservation_id;
    UPDATE lab_sessions SET available_workstations = available_workstations + v_qty WHERE session_id = v_session_id;
    
    RAISE NOTICE 'Reservation % cancelled; % workstations released.', p_reservation_id, v_qty;
END $$;

CALL cancel_reservation(1);
CALL cancel_reservation(1);

-- Step 7: Cursor for Low Capacity Sessions
DO $$
DECLARE
    v_rec RECORD;
    c_low_sessions CURSOR FOR 
        SELECT course_name, available_workstations 
        FROM lab_sessions 
        WHERE available_workstations <= 5;
BEGIN
    OPEN c_low_sessions;
    LOOP
        FETCH c_low_sessions INTO v_rec;
        EXIT WHEN NOT FOUND;
        RAISE NOTICE 'Low capacity session: "%" (% workstations remaining)', v_rec.course_name, v_rec.available_workstations;
    END LOOP;
    CLOSE c_low_sessions;
END $$;

-- Step 8: Exception Handling Demonstration
DO $$
BEGIN
    CALL reserve_workstations(1, 'Dr. Tembo', 0);
EXCEPTION
    WHEN invalid_parameter_value THEN
        RAISE NOTICE 'Handled Error: %', SQLERRM;
END $$;

-- Step 9: Final Table Check
SELECT * FROM lab_sessions ORDER BY session_id;
SELECT * FROM reservations ORDER BY reservation_id;