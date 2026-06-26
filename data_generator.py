"""
Banking / Transaction Analysis System - Synthetic Data Generator
------------------------------------------------------------------
Generates realistic CSVs for: customers, accounts, transactions, loans.
Designed so that downstream SQL analysis (fraud flags, segmentation,
loan default rates, credit utilization, cash flow trends) has REAL
patterns to discover, not just random noise.

Output: CSV files in ./output/ ready for MySQL LOAD DATA INFILE.
"""

import csv
import random
from datetime import datetime, timedelta
from faker import Faker
import os

fake = Faker()
random.seed(42)
Faker.seed(42)

OUTPUT_DIR = "output"
os.makedirs(OUTPUT_DIR, exist_ok=True)

# ----------------------------------------------------------------------
# CONFIG
# ----------------------------------------------------------------------
NUM_CUSTOMERS = 1500
REGIONS = ["North", "South", "East", "West", "Central"]

# Region income multipliers -> creates real regional income differences
REGION_INCOME_FACTOR = {
    "North": 1.15,
    "South": 0.90,
    "East": 1.05,
    "West": 1.20,
    "Central": 0.95,
}

ACCOUNT_TYPES = ["savings", "checking", "credit"]
MERCHANT_CATEGORIES = [
    "groceries", "dining", "utilities", "entertainment", "travel",
    "electronics", "healthcare", "rent", "fuel", "online_shopping",
    "insurance", "education", "subscriptions"
]
TRANSACTION_TYPES = ["purchase", "transfer", "withdrawal", "payment", "deposit"]

START_DATE = datetime(2024, 1, 1)
END_DATE = datetime(2025, 12, 31)

ANOMALY_RATE = 0.025  # ~2.5% of transactions are seeded anomalies

# ----------------------------------------------------------------------
# 1. CUSTOMERS
# ----------------------------------------------------------------------
customers = []
for cid in range(1, NUM_CUSTOMERS + 1):
    region = random.choice(REGIONS)
    base_income = random.gauss(60000, 20000)
    income = max(15000, base_income * REGION_INCOME_FACTOR[region])
    signup_date = fake.date_between(start_date=datetime(2018, 1, 1), end_date=datetime(2023, 12, 31))
    customers.append({
        "customer_id": cid,
        "full_name": fake.name(),
        "region": region,
        "income": round(income, 2),
        "signup_date": signup_date
    })

with open(f"{OUTPUT_DIR}/customers.csv", "w", newline="") as f:
    writer = csv.DictWriter(f, fieldnames=customers[0].keys())
    writer.writeheader()
    writer.writerows(customers)

print(f"Generated {len(customers)} customers")

# ----------------------------------------------------------------------
# 2. ACCOUNTS
# ----------------------------------------------------------------------
accounts = []
account_id = 1
customer_accounts_map = {}  # customer_id -> list of account_ids

for c in customers:
    customer_accounts_map[c["customer_id"]] = []

    # Every customer gets a checking account
    accounts.append({
        "account_id": account_id,
        "customer_id": c["customer_id"],
        "account_type": "checking",
        "credit_limit": "",
        "opened_date": fake.date_between(start_date=c["signup_date"], end_date=datetime(2024, 6, 1))
    })
    customer_accounts_map[c["customer_id"]].append(account_id)
    account_id += 1

    # 70% also get a savings account
    if random.random() < 0.7:
        accounts.append({
            "account_id": account_id,
            "customer_id": c["customer_id"],
            "account_type": "savings",
            "credit_limit": "",
            "opened_date": fake.date_between(start_date=c["signup_date"], end_date=datetime(2024, 6, 1))
        })
        customer_accounts_map[c["customer_id"]].append(account_id)
        account_id += 1

    # 45% get a credit account, with limit scaled to income
    if random.random() < 0.45:
        credit_limit = round(max(500, c["income"] * random.uniform(0.05, 0.25)), 2)
        accounts.append({
            "account_id": account_id,
            "customer_id": c["customer_id"],
            "account_type": "credit",
            "credit_limit": credit_limit,
            "opened_date": fake.date_between(start_date=c["signup_date"], end_date=datetime(2024, 6, 1))
        })
        customer_accounts_map[c["customer_id"]].append(account_id)
        account_id += 1

with open(f"{OUTPUT_DIR}/accounts.csv", "w", newline="") as f:
    writer = csv.DictWriter(f, fieldnames=accounts[0].keys())
    writer.writeheader()
    writer.writerows(accounts)

print(f"Generated {len(accounts)} accounts")

# ----------------------------------------------------------------------
# 3. TRANSACTIONS  (target: 50,000+)
# ----------------------------------------------------------------------
transactions = []
transaction_id = 1
TARGET_TRANSACTIONS = 55000

# Build a quick lookup: account_id -> (customer_id, account_type, credit_limit, income)
account_lookup = {}
customer_income = {c["customer_id"]: c["income"] for c in customers}
for a in accounts:
    account_lookup[a["account_id"]] = {
        "customer_id": a["customer_id"],
        "account_type": a["account_type"],
        "credit_limit": a["credit_limit"],
        "income": customer_income[a["customer_id"]]
    }

all_account_ids = list(account_lookup.keys())

def random_datetime(start, end):
    delta = end - start
    random_seconds = random.randint(0, int(delta.total_seconds()))
    return start + timedelta(seconds=random_seconds)

def normal_hour_datetime(start, end):
    """Generate a datetime biased toward normal daytime hours (8am-10pm)."""
    dt = random_datetime(start, end)
    hour = random.choices(
        population=list(range(24)),
        weights=[1,1,1,1,1,2,4,6,8,9,9,9,9,9,9,9,9,8,7,6,5,3,2,1],
        k=1
    )[0]
    return dt.replace(hour=hour, minute=random.randint(0,59), second=random.randint(0,59))

while transaction_id <= TARGET_TRANSACTIONS:
    acc_id = random.choice(all_account_ids)
    info = account_lookup[acc_id]
    income = info["income"]
    acc_type = info["account_type"]

    is_anomaly = random.random() < ANOMALY_RATE

    if is_anomaly:
        # Seed a recognizable anomaly pattern: unusually large amount OR odd-hour OR rapid burst
        anomaly_kind = random.choice(["large_amount", "odd_hour", "burst"])

        if anomaly_kind == "large_amount":
            amount = -round(random.uniform(income * 0.08, income * 0.25), 2)  # huge spend relative to income
            tx_date = random_datetime(START_DATE, END_DATE)
            txn_type = "purchase"
            merchant = random.choice(MERCHANT_CATEGORIES)

        elif anomaly_kind == "odd_hour":
            tx_date = random_datetime(START_DATE, END_DATE).replace(hour=random.choice([1,2,3,4]))
            amount = -round(random.uniform(200, 2000), 2)
            txn_type = "purchase"
            merchant = random.choice(MERCHANT_CATEGORIES)

        else:  # burst: write 3-5 transactions within a short window
            burst_count = random.randint(3, 5)
            base_time = random_datetime(START_DATE, END_DATE)
            for i in range(burst_count):
                if transaction_id > TARGET_TRANSACTIONS:
                    break
                burst_amount = -round(random.uniform(100, 900), 2)
                burst_time = base_time + timedelta(minutes=random.randint(1, 15) * i)
                transactions.append({
                    "transaction_id": transaction_id,
                    "account_id": acc_id,
                    "transaction_date": burst_time.strftime("%Y-%m-%d %H:%M:%S"),
                    "amount": burst_amount,
                    "merchant_category": random.choice(MERCHANT_CATEGORIES),
                    "transaction_type": "purchase"
                })
                transaction_id += 1
            continue  # skip the normal append below since we already added burst rows

    else:
        # Normal transaction pattern, scaled loosely to income
        tx_date = normal_hour_datetime(START_DATE, END_DATE)
        txn_type = random.choices(
            TRANSACTION_TYPES, weights=[55, 10, 10, 15, 10], k=1
        )[0]
        merchant = random.choice(MERCHANT_CATEGORIES)

        if txn_type == "deposit":
            amount = round(random.uniform(500, income / 12 * 1.1), 2)  # positive inflow (~monthly pay range)
        elif txn_type == "payment":
            amount = round(random.uniform(50, income / 24), 2)  # credit card payment, positive
        else:
            # spend scaled to income tier so segmentation patterns are real
            spend_factor = income / 60000
            amount = -round(random.uniform(5, 150) * spend_factor, 2)

    transactions.append({
        "transaction_id": transaction_id,
        "account_id": acc_id,
        "transaction_date": tx_date.strftime("%Y-%m-%d %H:%M:%S"),
        "amount": amount,
        "merchant_category": merchant,
        "transaction_type": txn_type
    })
    transaction_id += 1

with open(f"{OUTPUT_DIR}/transactions.csv", "w", newline="") as f:
    writer = csv.DictWriter(f, fieldnames=transactions[0].keys())
    writer.writeheader()
    writer.writerows(transactions)

print(f"Generated {len(transactions)} transactions")

# ----------------------------------------------------------------------
# 4. LOANS
# ----------------------------------------------------------------------
loans = []
loan_id = 1
NUM_LOANS = 350

# pick a subset of customers to have loans, weighted slightly toward lower income (more likely to need loans)
loan_customers = random.sample(customers, NUM_LOANS)

for c in loan_customers:
    loan_amount = round(random.uniform(2000, 40000), 2)
    interest_rate = round(random.uniform(4.5, 18.0), 2)
    issue_date = fake.date_between(start_date=datetime(2023, 1, 1), end_date=datetime(2025, 6, 1))
    term_months = random.choice([12, 24, 36, 48, 60])
    due_date = issue_date + timedelta(days=30 * term_months)

    # Default probability inversely related to income, plus interest rate effect
    base_default_prob = 0.05
    income_factor = max(0.5, 1.5 - (c["income"] / 80000))  # lower income -> higher factor
    rate_factor = interest_rate / 100
    default_prob = min(0.35, base_default_prob * income_factor + rate_factor * 0.4)

    roll = random.random()
    if roll < default_prob:
        status = "defaulted"
    elif issue_date < datetime(2024, 6, 1).date() and random.random() < 0.4:
        status = "paid"
    else:
        status = "current"

    loans.append({
        "loan_id": loan_id,
        "customer_id": c["customer_id"],
        "loan_amount": loan_amount,
        "interest_rate": interest_rate,
        "issue_date": issue_date,
        "due_date": due_date,
        "status": status
    })
    loan_id += 1

with open(f"{OUTPUT_DIR}/loans.csv", "w", newline="") as f:
    writer = csv.DictWriter(f, fieldnames=loans[0].keys())
    writer.writeheader()
    writer.writerows(loans)

print(f"Generated {len(loans)} loans")
print("\nAll CSV files written to ./output/")
print("Files: customers.csv, accounts.csv, transactions.csv, loans.csv")
