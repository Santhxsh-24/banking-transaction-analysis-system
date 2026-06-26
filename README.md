# Banking / Transaction Analysis System

A SQL portfolio project simulating a bank's internal analytics pipeline built on a synthetic dataset of 55,000+ transactions across 1,500 customers to demonstrate fraud detection, customer segmentation, and credit/loan risk reporting using advanced SQL.

## What this project does

- **Fraud detection pipeline**  flags statistically anomalous transactions (3-sigma outliers), odd-hour purchases, and rapid-fire transaction bursts using window functions and CTEs.
- **Customer segmentation**  buckets customers by income tier, region, and transaction frequency/recency (RFM-style) using `GROUP BY` and `CASE` logic.
- **Business reporting**  loan default rates by segment, credit utilization with risk tiers, and monthly/regional cash flow trends.

All analysis is built with **window functions, CTEs, and subqueries**  no stored procedures or external tools required, just SQL.

## Tech stack

- **MySQL 8.0+** (uses window functions, CTEs, and `STDDEV()` — all native to MySQL 8)
- **Python 3 + Faker** for synthetic data generation

## Schema

```
customers (customer_id, full_name, region, income, signup_date)
        |
        ▼
accounts (account_id, customer_id, account_type, credit_limit, opened_date)
        |
        ▼
transactions (transaction_id, account_id, transaction_date, amount,
              merchant_category, transaction_type)

customers (customer_id) ──▶ loans (loan_id, customer_id, loan_amount,
                                    interest_rate, issue_date, due_date, status)
```

- Each customer has 1–3 accounts (checking, savings, credit).
- Transaction amounts are signed: negative = spend/withdrawal, positive = deposit/payment.
- ~2.5% of transactions are deliberately seeded anomalies (oversized purchases, odd-hour activity, rapid-fire bursts) so the fraud-detection queries have real patterns to catch.
- Loan default probability is weighted by income and interest rate, so default-rate segmentation reflects realistic risk patterns.

## Project structure

```
banking-sql-project/
├── schema.sql                          # CREATE TABLE statements
├── data_generator.py                   # generates realistic CSVs (customers, accounts, transactions, loans)
├── load_data.sql                       # LOAD DATA INFILE statements + notes on common gotchas
├── queries/
│   ├── 01_window_functions_and_ctes.sql
│   ├── 02_fraud_detection.sql
│   ├── 03_customer_segmentation.sql
│   └── 04_business_reports.sql
└── README.md
```

## How to run it

1. **Create the schema**
   ```bash
   mysql -u youruser -p < schema.sql
   ```

2. **Generate the data**
   ```bash
   pip install faker
   python3 data_generator.py
   ```
   This produces `customers.csv`, `accounts.csv`, `transactions.csv`, and `loans.csv` in an `output/` folder.

3. **Load the data**
   See `load_data.sql` for full instructions. Short version: find your server's `secure_file_priv` directory (`SHOW VARIABLES LIKE 'secure_file_priv';`), copy the CSVs there, then run the `LOAD DATA INFILE` statements in order (customers → accounts → transactions → loans).

   > **Gotcha:** if your CSVs have Windows line endings (`\r\n`), use `LINES TERMINATED BY '\r\n'` — otherwise MySQL throws a truncation error on the last column of `transactions` and `loans` (both end in an `ENUM`, which is strict about trailing characters).

4. **Run the analysis queries**
   Each file in `queries/` is self-contained and runnable independently. Run them in order (01 → 04) if you want to build up the views progressively, since later reports occasionally reuse view definitions created earlier.

## Sample insights this project surfaces

- **Fraud detection:** transactions flagged as 3+ standard deviations from an account's typical spend, purchases made between 1–4am, and clusters of 3+ transactions within 15 minutes on the same account.
- **Segmentation:** average spend and transaction frequency broken down by region × income tier, plus RFM-style "Active / Cooling Off / Dormant" recency tags per customer.
- **Risk reporting:** loan default rate by region and income tier (lower-income segments show measurably higher default rates, consistent with the seeded risk model), credit utilization with Low/Medium/High risk tiers, and net cash flow trends by month and region.

## Why synthetic data

Real banking transaction data is sensitive and not publicly available at this scale. This project generates a realistic synthetic dataset with intentionally seeded patterns (regional income variation, anomalous transactions, income-correlated loan defaults) so the SQL analysis has genuine signal to find — rather than querying pure random noise.
