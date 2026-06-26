-- ============================================================
-- 02 — Fraud Detection / Anomaly Flagging
-- ============================================================
USE banking_analysis;

-- 2.1 Statistical outlier amounts (3-sigma rule, per account)
WITH account_stats AS (
    SELECT
        account_id,
        AVG(amount) AS avg_amount,
        STDDEV(amount) AS stddev_amount
    FROM transactions
    WHERE amount < 0
    GROUP BY account_id
)
SELECT
    t.transaction_id,
    t.account_id,
    t.transaction_date,
    t.amount,
    s.avg_amount,
    s.stddev_amount,
    CASE
        WHEN ABS(t.amount - s.avg_amount) > 3 * s.stddev_amount THEN 'FLAGGED: Outlier amount'
        ELSE 'normal'
    END AS fraud_flag
FROM transactions t
JOIN account_stats s ON t.account_id = s.account_id
WHERE t.amount < 0
HAVING fraud_flag = 'FLAGGED: Outlier amount'
ORDER BY ABS(t.amount) DESC;


-- 2.2 Odd-hour transactions (1am–4am purchases)
SELECT
    transaction_id,
    account_id,
    transaction_date,
    HOUR(transaction_date) AS txn_hour,
    amount,
    transaction_type,
    'FLAGGED: Odd hour' AS fraud_flag
FROM transactions
WHERE HOUR(transaction_date) BETWEEN 1 AND 4
  AND transaction_type = 'purchase'
ORDER BY transaction_date;


-- 2.3 Rapid-fire bursts (multiple spends within 15 min, same account)
WITH txn_gaps AS (
    SELECT
        transaction_id,
        account_id,
        transaction_date,
        amount,
        TIMESTAMPDIFF(
            MINUTE,
            LAG(transaction_date) OVER (PARTITION BY account_id ORDER BY transaction_date),
            transaction_date
        ) AS minutes_since_last
    FROM transactions
    WHERE amount < 0
)
SELECT
    transaction_id,
    account_id,
    transaction_date,
    amount,
    minutes_since_last,
    'FLAGGED: Rapid-fire burst' AS fraud_flag
FROM txn_gaps
WHERE minutes_since_last IS NOT NULL
  AND minutes_since_last <= 15
ORDER BY account_id, transaction_date;


-- 2.4 Combined fraud dashboard view
CREATE OR REPLACE VIEW vw_fraud_flags AS
WITH account_stats AS (
    SELECT account_id, AVG(amount) AS avg_amount, STDDEV(amount) AS stddev_amount
    FROM transactions WHERE amount < 0
    GROUP BY account_id
),
txn_gaps AS (
    SELECT
        transaction_id, account_id, transaction_date, amount,
        TIMESTAMPDIFF(MINUTE, LAG(transaction_date) OVER (PARTITION BY account_id ORDER BY transaction_date), transaction_date) AS minutes_since_last
    FROM transactions WHERE amount < 0
)
SELECT
    t.transaction_id,
    t.account_id,
    t.transaction_date,
    t.amount,
    t.transaction_type,
    CASE
        WHEN ABS(t.amount - s.avg_amount) > 3 * s.stddev_amount THEN 'Outlier amount'
        WHEN HOUR(t.transaction_date) BETWEEN 1 AND 4 AND t.transaction_type = 'purchase' THEN 'Odd hour'
        WHEN g.minutes_since_last IS NOT NULL AND g.minutes_since_last <= 15 THEN 'Rapid-fire burst'
        ELSE NULL
    END AS fraud_flag
FROM transactions t
JOIN account_stats s ON t.account_id = s.account_id
LEFT JOIN txn_gaps g ON t.transaction_id = g.transaction_id
HAVING fraud_flag IS NOT NULL;

-- Usage:
-- SELECT * FROM vw_fraud_flags ORDER BY transaction_date DESC LIMIT 100;
