-- ============================================================
-- 01 — Window Functions & CTEs
-- ============================================================
USE banking_analysis;

-- 1.1 Running balance per account
SELECT
    account_id,
    transaction_date,
    amount,
    transaction_type,
    SUM(amount) OVER (
        PARTITION BY account_id
        ORDER BY transaction_date
    ) AS running_balance
FROM transactions
WHERE account_id = 1
ORDER BY transaction_date;


-- 1.2 Month-over-month spend per customer (LAG)
WITH monthly_spend AS (
    SELECT
        a.customer_id,
        DATE_FORMAT(t.transaction_date, '%Y-%m') AS month,
        SUM(CASE WHEN t.amount < 0 THEN -t.amount ELSE 0 END) AS total_spend
    FROM transactions t
    JOIN accounts a ON t.account_id = a.account_id
    GROUP BY a.customer_id, DATE_FORMAT(t.transaction_date, '%Y-%m')
)
SELECT
    customer_id,
    month,
    total_spend,
    LAG(total_spend) OVER (PARTITION BY customer_id ORDER BY month) AS prev_month_spend,
    total_spend - LAG(total_spend) OVER (PARTITION BY customer_id ORDER BY month) AS spend_change
FROM monthly_spend
ORDER BY customer_id, month;


-- 1.3 Rank top spenders within each region
WITH customer_totals AS (
    SELECT
        c.customer_id,
        c.full_name,
        c.region,
        SUM(CASE WHEN t.amount < 0 THEN -t.amount ELSE 0 END) AS total_spend
    FROM customers c
    JOIN accounts a ON c.customer_id = a.customer_id
    JOIN transactions t ON a.account_id = t.account_id
    GROUP BY c.customer_id, c.full_name, c.region
)
SELECT
    customer_id,
    full_name,
    region,
    total_spend,
    RANK() OVER (PARTITION BY region ORDER BY total_spend DESC) AS region_rank
FROM customer_totals
ORDER BY region, region_rank;
