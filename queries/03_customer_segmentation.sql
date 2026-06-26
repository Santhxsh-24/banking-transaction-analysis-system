-- ============================================================
-- 03 — Customer Segmentation
-- ============================================================
USE banking_analysis;

-- 3.1 Income tier segmentation
SELECT
    customer_id,
    full_name,
    region,
    income,
    CASE
        WHEN income < 40000 THEN 'Low Income'
        WHEN income BETWEEN 40000 AND 80000 THEN 'Middle Income'
        WHEN income BETWEEN 80001 AND 120000 THEN 'Upper-Middle Income'
        ELSE 'High Income'
    END AS income_tier
FROM customers;


-- 3.2 Spend & frequency by income tier and region
WITH customer_segments AS (
    SELECT
        c.customer_id,
        c.region,
        CASE
            WHEN c.income < 40000 THEN 'Low Income'
            WHEN c.income BETWEEN 40000 AND 80000 THEN 'Middle Income'
            WHEN c.income BETWEEN 80001 AND 120000 THEN 'Upper-Middle Income'
            ELSE 'High Income'
        END AS income_tier
    FROM customers c
),
customer_activity AS (
    SELECT
        a.customer_id,
        COUNT(t.transaction_id) AS txn_count,
        SUM(CASE WHEN t.amount < 0 THEN -t.amount ELSE 0 END) AS total_spend
    FROM accounts a
    JOIN transactions t ON a.account_id = t.account_id
    GROUP BY a.customer_id
)
SELECT
    s.region,
    s.income_tier,
    COUNT(DISTINCT s.customer_id) AS num_customers,
    ROUND(AVG(ca.txn_count), 1) AS avg_txn_count,
    ROUND(AVG(ca.total_spend), 2) AS avg_total_spend
FROM customer_segments s
JOIN customer_activity ca ON s.customer_id = ca.customer_id
GROUP BY s.region, s.income_tier
ORDER BY s.region, s.income_tier;


-- 3.3 RFM-style frequency & recency segmentation
WITH customer_frequency AS (
    SELECT
        a.customer_id,
        COUNT(t.transaction_id) AS txn_count,
        MAX(t.transaction_date) AS last_txn_date,
        DATEDIFF(
            (SELECT MAX(transaction_date) FROM transactions),
            MAX(t.transaction_date)
        ) AS days_since_last_txn
    FROM accounts a
    JOIN transactions t ON a.account_id = t.account_id
    GROUP BY a.customer_id
)
SELECT
    customer_id,
    txn_count,
    days_since_last_txn,
    CASE
        WHEN txn_count >= 40 THEN 'High Frequency'
        WHEN txn_count BETWEEN 15 AND 39 THEN 'Medium Frequency'
        ELSE 'Low Frequency'
    END AS frequency_segment,
    CASE
        WHEN days_since_last_txn <= 30 THEN 'Active'
        WHEN days_since_last_txn BETWEEN 31 AND 90 THEN 'Cooling Off'
        ELSE 'Dormant'
    END AS recency_segment
FROM customer_frequency
ORDER BY txn_count DESC;


-- 3.4 Reusable segmentation view
CREATE OR REPLACE VIEW vw_customer_segments AS
WITH customer_segments AS (
    SELECT
        c.customer_id, c.full_name, c.region, c.income,
        CASE
            WHEN c.income < 40000 THEN 'Low Income'
            WHEN c.income BETWEEN 40000 AND 80000 THEN 'Middle Income'
            WHEN c.income BETWEEN 80001 AND 120000 THEN 'Upper-Middle Income'
            ELSE 'High Income'
        END AS income_tier
    FROM customers c
),
customer_activity AS (
    SELECT
        a.customer_id,
        COUNT(t.transaction_id) AS txn_count,
        SUM(CASE WHEN t.amount < 0 THEN -t.amount ELSE 0 END) AS total_spend,
        DATEDIFF((SELECT MAX(transaction_date) FROM transactions), MAX(t.transaction_date)) AS days_since_last_txn
    FROM accounts a
    JOIN transactions t ON a.account_id = t.account_id
    GROUP BY a.customer_id
)
SELECT
    s.customer_id, s.full_name, s.region, s.income, s.income_tier,
    ca.txn_count, ca.total_spend, ca.days_since_last_txn,
    CASE
        WHEN ca.txn_count >= 40 THEN 'High Frequency'
        WHEN ca.txn_count BETWEEN 15 AND 39 THEN 'Medium Frequency'
        ELSE 'Low Frequency'
    END AS frequency_segment
FROM customer_segments s
JOIN customer_activity ca ON s.customer_id = ca.customer_id;

-- Usage:
-- SELECT * FROM vw_customer_segments LIMIT 50;
