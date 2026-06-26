-- ============================================================
-- 04 — Business Reports: Loan Defaults, Credit Utilization, Cash Flow
-- ============================================================
USE banking_analysis;

-- 4.1 Loan default rate by region and income tier
WITH customer_tiers AS (
    SELECT
        customer_id,
        region,
        CASE
            WHEN income < 40000 THEN 'Low Income'
            WHEN income BETWEEN 40000 AND 80000 THEN 'Middle Income'
            WHEN income BETWEEN 80001 AND 120000 THEN 'Upper-Middle Income'
            ELSE 'High Income'
        END AS income_tier
    FROM customers
)
SELECT
    ct.region,
    ct.income_tier,
    COUNT(l.loan_id) AS total_loans,
    SUM(CASE WHEN l.status = 'defaulted' THEN 1 ELSE 0 END) AS defaulted_loans,
    ROUND(
        SUM(CASE WHEN l.status = 'defaulted' THEN 1 ELSE 0 END) * 100.0 / COUNT(l.loan_id),
        2
    ) AS default_rate_pct
FROM loans l
JOIN customer_tiers ct ON l.customer_id = ct.customer_id
GROUP BY ct.region, ct.income_tier
ORDER BY default_rate_pct DESC;


-- 4.2 Credit utilization by account, with risk tiers
WITH credit_balances AS (
    SELECT
        a.account_id,
        a.customer_id,
        a.credit_limit,
        SUM(t.amount) AS current_balance
    FROM accounts a
    JOIN transactions t ON a.account_id = t.account_id
    WHERE a.account_type = 'credit'
    GROUP BY a.account_id, a.customer_id, a.credit_limit
)
SELECT
    account_id,
    customer_id,
    credit_limit,
    ABS(current_balance) AS amount_owed,
    ROUND(ABS(current_balance) / credit_limit * 100, 2) AS utilization_pct,
    CASE
        WHEN ABS(current_balance) / credit_limit > 0.7 THEN 'High Risk'
        WHEN ABS(current_balance) / credit_limit BETWEEN 0.3 AND 0.7 THEN 'Medium Risk'
        ELSE 'Low Risk'
    END AS risk_tier
FROM credit_balances
WHERE current_balance < 0
ORDER BY utilization_pct DESC;


-- 4.3 Monthly cash flow trends (inflow vs outflow)
SELECT
    DATE_FORMAT(t.transaction_date, '%Y-%m') AS month,
    SUM(CASE WHEN t.amount > 0 THEN t.amount ELSE 0 END) AS total_inflow,
    SUM(CASE WHEN t.amount < 0 THEN -t.amount ELSE 0 END) AS total_outflow,
    SUM(t.amount) AS net_cash_flow
FROM transactions t
GROUP BY DATE_FORMAT(t.transaction_date, '%Y-%m')
ORDER BY month;


-- 4.4 Cash flow trend by region
SELECT
    c.region,
    DATE_FORMAT(t.transaction_date, '%Y-%m') AS month,
    SUM(CASE WHEN t.amount > 0 THEN t.amount ELSE 0 END) AS total_inflow,
    SUM(CASE WHEN t.amount < 0 THEN -t.amount ELSE 0 END) AS total_outflow
FROM transactions t
JOIN accounts a ON t.account_id = a.account_id
JOIN customers c ON a.customer_id = c.customer_id
GROUP BY c.region, DATE_FORMAT(t.transaction_date, '%Y-%m')
ORDER BY c.region, month;


-- 4.5 Reusable views
CREATE OR REPLACE VIEW vw_loan_default_rates AS
WITH customer_tiers AS (
    SELECT customer_id, region,
        CASE
            WHEN income < 40000 THEN 'Low Income'
            WHEN income BETWEEN 40000 AND 80000 THEN 'Middle Income'
            WHEN income BETWEEN 80001 AND 120000 THEN 'Upper-Middle Income'
            ELSE 'High Income'
        END AS income_tier
    FROM customers
)
SELECT
    ct.region, ct.income_tier,
    COUNT(l.loan_id) AS total_loans,
    SUM(CASE WHEN l.status = 'defaulted' THEN 1 ELSE 0 END) AS defaulted_loans,
    ROUND(SUM(CASE WHEN l.status = 'defaulted' THEN 1 ELSE 0 END) * 100.0 / COUNT(l.loan_id), 2) AS default_rate_pct
FROM loans l
JOIN customer_tiers ct ON l.customer_id = ct.customer_id
GROUP BY ct.region, ct.income_tier;

CREATE OR REPLACE VIEW vw_credit_utilization AS
WITH credit_balances AS (
    SELECT a.account_id, a.customer_id, a.credit_limit, SUM(t.amount) AS current_balance
    FROM accounts a
    JOIN transactions t ON a.account_id = t.account_id
    WHERE a.account_type = 'credit'
    GROUP BY a.account_id, a.customer_id, a.credit_limit
)
SELECT
    account_id, customer_id, credit_limit, ABS(current_balance) AS amount_owed,
    ROUND(ABS(current_balance) / credit_limit * 100, 2) AS utilization_pct,
    CASE
        WHEN ABS(current_balance) / credit_limit > 0.7 THEN 'High Risk'
        WHEN ABS(current_balance) / credit_limit BETWEEN 0.3 AND 0.7 THEN 'Medium Risk'
        ELSE 'Low Risk'
    END AS risk_tier
FROM credit_balances
WHERE current_balance < 0;

CREATE OR REPLACE VIEW vw_monthly_cash_flow AS
SELECT
    DATE_FORMAT(t.transaction_date, '%Y-%m') AS month,
    SUM(CASE WHEN t.amount > 0 THEN t.amount ELSE 0 END) AS total_inflow,
    SUM(CASE WHEN t.amount < 0 THEN -t.amount ELSE 0 END) AS total_outflow,
    SUM(t.amount) AS net_cash_flow
FROM transactions t
GROUP BY DATE_FORMAT(t.transaction_date, '%Y-%m');
