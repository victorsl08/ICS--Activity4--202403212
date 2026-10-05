-- ============================================================
-- SCENARIO 3: Library Book Loans
-- File Name: scenario3_[StudentNumber].sql
-- ============================================================

-- Step 1: Create Tables and Insert Initial Data
CREATE TABLE IF NOT EXISTS books (
    book_id SERIAL PRIMARY KEY,
    title VARCHAR(100) NOT NULL,
    available_copies INT NOT NULL CHECK (available_copies >= 0)
);

CREATE TABLE IF NOT EXISTS book_checkouts (
    checkout_id SERIAL PRIMARY KEY,
    book_id INT REFERENCES books(book_id),
    patron_name VARCHAR(100) NOT NULL,
    copies_borrowed INT NOT NULL CHECK (copies_borrowed > 0),
    status VARCHAR(20) NOT NULL CHECK (status IN ('BORROWED', 'RETURNED'))
);

TRUNCATE TABLE book_checkouts, books RESTART IDENTITY CASCADE;

INSERT INTO books (title, available_copies) VALUES 
('Database System Concepts', 5),
('Clean Code', 1),
('Introduction to Algorithms', 0);


-- Step 2: Conditional Logic (IF/ELSIF/ELSE)
DO $$
DECLARE
    v_copies INT;
BEGIN
    SELECT available_copies INTO v_copies 
    FROM books WHERE book_id = 2;

    IF v_copies = 0 THEN
        RAISE NOTICE 'Book is currently checked out';
    ELSIF v_copies <= 2 THEN
        RAISE NOTICE 'Limited copies remaining: % copy left', v_copies;
    ELSE
        RAISE NOTICE 'Multiple copies available: % total', v_copies;
    END IF;
END $$;


-- Step 3: Loops (WHILE and FOR)
DO $$
DECLARE
    v_shelf INT := 1;
BEGIN
    WHILE v_shelf <= 3 LOOP
        RAISE NOTICE 'Scanning shelf section #%', v_shelf;
        v_shelf := v_shelf + 1;
    END LOOP;

    FOR v_book IN 1..3 LOOP
        RAISE NOTICE 'Validating RFID tag #%', v_book;
    END LOOP;
END $$;


-- Step 4: Procedure to Checkout Book
CREATE OR REPLACE PROCEDURE checkout_book(
    p_book_id INT,
    p_patron_name VARCHAR,
    p_copies INT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_available INT;
BEGIN
    IF p_copies <= 0 THEN
        RAISE EXCEPTION 'Copies requested must be positive' USING ERRCODE = '22023';
    END IF;

    SELECT available_copies INTO v_available 
    FROM books WHERE book_id = p_book_id FOR UPDATE;

    IF NOT FOUND THEN
        RAISE NOTICE 'Book ID % does not exist.', p_book_id;
        RETURN;
    ELSIF v_available < p_copies THEN
        RAISE NOTICE 'Cannot checkout % copies; only % available.', p_copies, v_available;
        RETURN;
    END IF;

    UPDATE books 
    SET available_copies = available_copies - p_copies 
    WHERE book_id = p_book_id;

    INSERT INTO book_checkouts (book_id, patron_name, copies_borrowed, status) 
    VALUES (p_book_id, p_patron_name, p_copies, 'BORROWED');
    
    RAISE NOTICE 'Successfully checked out % copy to %.', p_copies, p_patron_name;
END $$;


-- Step 5: Test Checkout Book Procedure
CALL checkout_book(1, 'Grace Hopper', 2);
CALL checkout_book(2, 'Alan Turing', 1);
CALL checkout_book(3, 'Ada Lovelace', 1); -- Unavailable book test


-- Step 6: Procedure to Return Book
CREATE OR REPLACE PROCEDURE return_book(p_checkout_id INT)
LANGUAGE plpgsql
AS $$
DECLARE
    v_book_id INT;
    v_qty INT;
    v_status VARCHAR;
BEGIN
    SELECT book_id, copies_borrowed, status 
    INTO v_book_id, v_qty, v_status 
    FROM book_checkouts WHERE checkout_id = p_checkout_id FOR UPDATE;

    IF NOT FOUND THEN
        RAISE NOTICE 'Checkout record % not found.', p_checkout_id;
        RETURN;
    ELSIF v_status = 'RETURNED' THEN
        RAISE NOTICE 'Checkout % has already been returned.', p_checkout_id;
        RETURN;
    END IF;

    UPDATE book_checkouts SET status = 'RETURNED' WHERE checkout_id = p_checkout_id;
    UPDATE books SET available_copies = available_copies + v_qty WHERE book_id = v_book_id;
    
    RAISE NOTICE 'Checkout % returned; % copy restored to library.', p_checkout_id, v_qty;
END $$;

CALL return_book(1);
CALL return_book(1); -- Double return check


-- Step 7: Cursor for Low Copy Books
DO $$
DECLARE
    v_rec RECORD;
    c_low_books CURSOR FOR 
        SELECT title, available_copies 
        FROM books 
        WHERE available_copies <= 2;
BEGIN
    OPEN c_low_books;
    LOOP
        FETCH c_low_books INTO v_rec;
        EXIT WHEN NOT FOUND;
        RAISE NOTICE 'Low availability book: "%" (% copies available)', v_rec.title, v_rec.available_copies;
    END LOOP;
    CLOSE c_low_books;
END $$;


-- Step 8: Exception Handling Demonstration
DO $$
BEGIN
    CALL checkout_book(1, 'Linus Torvalds', 0);
EXCEPTION
    WHEN invalid_parameter_value THEN
        RAISE NOTICE 'Handled Error: %', SQLERRM;
END $$;


-- Step 9: Final Status Verification
SELECT * FROM books ORDER BY book_id;
SELECT * FROM book_checkouts ORDER BY checkout_id;