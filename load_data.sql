-- ============================================================
-- Loading the generated CSVs into MySQL
-- ============================================================
-- 1. Run data_generator.py to produce customers.csv, accounts.csv,
--    transactions.csv, loans.csv in an /output folder.
-- 2. Find your server's allowed import folder:
--      SHOW VARIABLES LIKE 'secure_file_priv';
-- 3. Copy the 4 CSVs into that folder.
-- 4. Run the statements below, using the FULL PATH to each file
--    (forward slashes, even on Windows), in this order:
--    customers -> accounts -> transactions -> loans
--
-- NOTE: if you generated the CSVs on Windows, lines end in \r\n.
-- Tables with an ENUM as the LAST column (transactions, loans)
-- need LINES TERMINATED BY '\r\n' or MySQL will throw
-- "Error 1265: Data truncated for column ... " because the
-- trailing \r gets appended to the enum value.
-- ============================================================

USE banking_analysis;

LOAD DATA INFILE '/path/to/Uploads/customers.csv'
INTO TABLE customers
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 ROWS;

LOAD DATA INFILE '/path/to/Uploads/accounts.csv'
INTO TABLE accounts
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 ROWS
(account_id, customer_id, account_type, @credit_limit, opened_date)
SET credit_limit = IF(@credit_limit='', NULL, @credit_limit);

LOAD DATA INFILE '/path/to/Uploads/transactions.csv'
INTO TABLE transactions
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 ROWS;

LOAD DATA INFILE '/path/to/Uploads/loans.csv'
INTO TABLE loans
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 ROWS;

-- Sanity checks
SELECT COUNT(*) FROM customers;
SELECT COUNT(*) FROM accounts;
SELECT COUNT(*) FROM transactions;
SELECT COUNT(*) FROM loans;
