-- ============================================================
-- SCENARIO 4: University Equipment Loans
-- File Name: scenario4_[StudentNumber].sql
-- ============================================================

-- Step 1: Create Tables and Insert Initial Data
CREATE TABLE IF NOT EXISTS equipment (
    equipment_id SERIAL PRIMARY KEY,
    equipment_name VARCHAR(100) NOT NULL,
    available_units INT NOT NULL CHECK (available_units >= 0)
);

CREATE TABLE IF NOT EXISTS equipment_loans (
    loan_id SERIAL PRIMARY KEY,
    equipment_id INT REFERENCES equipment(equipment_id),
    borrower_name VARCHAR(100) NOT NULL,
    units_borrowed INT NOT NULL CHECK (units_borrowed > 0),
    status VARCHAR(20) NOT NULL CHECK (status IN ('BORROWED', 'RETURNED'))
);

TRUNCATE TABLE equipment_loans, equipment RESTART IDENTITY CASCADE;

INSERT INTO equipment (equipment_name, available_units) VALUES 
('HD Projector', 10),
('DSLR Camera', 2),
('Wireless Microphone Set', 0);


-- Step 2: Conditional Logic (IF/ELSIF/ELSE)
DO $$
DECLARE
    v_units INT;
BEGIN
    SELECT available_units INTO v_units 
    FROM equipment WHERE equipment_id = 2;

    IF v_units = 0 THEN
        RAISE NOTICE 'Equipment is out of stock';
    ELSIF v_units <= 2 THEN
        RAISE NOTICE 'Low stock warning: % units left', v_units;
    ELSE
        RAISE NOTICE 'Equipment in stock: % units available', v_units;
    END IF;
END $$;


-- Step 3: Loops (WHILE and FOR)
DO $$
DECLARE
    v_inspection INT := 1;
BEGIN
    WHILE v_inspection <= 3 LOOP
        RAISE NOTICE 'Routine equipment inspection #%', v_inspection;
        v_inspection := v_inspection + 1;
    END LOOP;

    FOR v_item IN 1..3 LOOP
        RAISE NOTICE 'Verifying asset barcode #%', v_item;
    END LOOP;
END $$;


-- Step 4: Procedure to Issue Equipment Loan
CREATE OR REPLACE PROCEDURE loan_equipment(
    p_equipment_id INT,
    p_borrower_name VARCHAR,
    p_units INT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_available INT;
BEGIN
    IF p_units <= 0 THEN
        RAISE EXCEPTION 'Units requested must be positive' USING ERRCODE = '22023';
    END IF;

    SELECT available_units INTO v_available 
    FROM equipment WHERE equipment_id = p_equipment_id FOR UPDATE;

    IF NOT FOUND THEN
        RAISE NOTICE 'Equipment ID % does not exist.', p_equipment_id;
        RETURN;
    ELSIF v_available < p_units THEN
        RAISE NOTICE 'Cannot loan % units; only % available.', p_units, v_available;
        RETURN;
    END IF;

    UPDATE equipment 
    SET available_units = available_units - p_units 
    WHERE equipment_id = p_equipment_id;

    INSERT INTO equipment_loans (equipment_id, borrower_name, units_borrowed, status) 
    VALUES (p_equipment_id, p_borrower_name, p_units, 'BORROWED');
    
    RAISE NOTICE 'Successfully loaned % units to %.', p_units, p_borrower_name;
END $$;


-- Step 5: Test Loan Equipment Procedure
CALL loan_equipment(1, 'Alice Banda', 3);
CALL loan_equipment(2, 'Bob Phiri', 2);
CALL loan_equipment(3, 'Charlie Tembo', 1); -- Exceeds capacity (0 available)


-- Step 6: Procedure to Return Equipment
CREATE OR REPLACE PROCEDURE return_equipment(p_loan_id INT)
LANGUAGE plpgsql
AS $$
DECLARE
    v_equipment_id INT;
    v_qty INT;
    v_status VARCHAR;
BEGIN
    SELECT equipment_id, units_borrowed, status 
    INTO v_equipment_id, v_qty, v_status 
    FROM equipment_loans WHERE loan_id = p_loan_id FOR UPDATE;

    IF NOT FOUND THEN
        RAISE NOTICE 'Loan record % not found.', p_loan_id;
        RETURN;
    ELSIF v_status = 'RETURNED' THEN
        RAISE NOTICE 'Loan % has already been returned.', p_loan_id;
        RETURN;
    END IF;

    UPDATE equipment_loans SET status = 'RETURNED' WHERE loan_id = p_loan_id;
    UPDATE equipment SET available_units = available_units + v_qty WHERE equipment_id = v_equipment_id;
    
    RAISE NOTICE 'Loan % returned; % units restored to inventory.', p_loan_id, v_qty;
END $$;

CALL return_equipment(1);
CALL return_equipment(1); -- Double return check


-- Step 7: Cursor for Low Inventory Items
DO $$
DECLARE
    v_rec RECORD;
    c_low_stock CURSOR FOR 
        SELECT equipment_name, available_units 
        FROM equipment 
        WHERE available_units <= 2;
BEGIN
    OPEN c_low_stock;
    LOOP
        FETCH c_low_stock INTO v_rec;
        EXIT WHEN NOT FOUND;
        RAISE NOTICE 'Low stock item: "%" (% units available)', v_rec.equipment_name, v_rec.available_units;
    END LOOP;
    CLOSE c_low_stock;
END $$;


-- Step 8: Exception Handling Demonstration
DO $$
BEGIN
    CALL loan_equipment(1, 'Dave Mulenga', 0);
EXCEPTION
    WHEN invalid_parameter_value THEN
        RAISE NOTICE 'Handled Error: %', SQLERRM;
END $$;


-- Step 9: Final Status Verification
SELECT * FROM equipment ORDER BY equipment_id;
SELECT * FROM equipment_loans ORDER BY loan_id;