
-- Banking / Transaction Analysis System — Schema
-- MySQL 8.0+


CREATE DATABASE IF NOT EXISTS banking_analysis;
USE banking_analysis;

-- 1. Customers
CREATE TABLE customers (
    customer_id   INT AUTO_INCREMENT PRIMARY KEY,
    full_name     VARCHAR(100),
    region        VARCHAR(50),
    income        DECIMAL(12,2),
    signup_date   DATE
);

-- 2. Accounts (each customer can have multiple accounts)
CREATE TABLE accounts (
    account_id     INT AUTO_INCREMENT PRIMARY KEY,
    customer_id    INT,
    account_type   ENUM('savings', 'checking', 'credit') NOT NULL,
    credit_limit   DECIMAL(12,2) DEFAULT NULL,  -- only relevant for credit accounts
    opened_date    DATE,
    FOREIGN KEY (customer_id) REFERENCES customers(customer_id)
);

-- 3. Transactions (fact table — 50,000+ rows)
CREATE TABLE transactions (
    transaction_id     BIGINT AUTO_INCREMENT PRIMARY KEY,
    account_id          INT,
    transaction_date    DATETIME,
    amount               DECIMAL(12,2),   -- negative = debit/spend, positive = credit/deposit
    merchant_category   VARCHAR(50),
    transaction_type    ENUM('purchase','transfer','withdrawal','payment','deposit'),
    FOREIGN KEY (account_id) REFERENCES accounts(account_id)
);

-- 4. Loans (for default-rate analysis)
CREATE TABLE loans (
    loan_id        INT AUTO_INCREMENT PRIMARY KEY,
    customer_id    INT,
    loan_amount    DECIMAL(12,2),
    interest_rate  DECIMAL(5,2),
    issue_date     DATE,
    due_date       DATE,
    status         ENUM('current','paid','defaulted') DEFAULT 'current',
    FOREIGN KEY (customer_id) REFERENCES customers(customer_id)
);
