"""
Generates synthetic data for the Telecom/Retail Store Performance SQL project.
Models a Cricket Wireless-style prepaid retail chain: stores, employees,
customers, plans, and transactions. Reproducible via a fixed random seed.
"""
import random
import datetime
import csv
import os

random.seed(42)

PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_DIR = os.path.join(PROJECT_ROOT, "data")
os.makedirs(OUT_DIR, exist_ok=True)

# ---------------------------------------------------------------------------
# Plans (dimension table)
# ---------------------------------------------------------------------------
plans = [
    (1, "Basic 2GB",       30.00,  2, "Prepaid"),
    (2, "Value 5GB",       40.00,  5, "Prepaid"),
    (3, "Standard 10GB",   45.00, 10, "Prepaid"),
    (4, "Unlimited Core",  55.00, 35, "Prepaid"),
    (5, "Unlimited Plus",  60.00, 50, "Prepaid"),
    (6, "Unlimited Metro", 65.00, 60, "Prepaid"),
]

# ---------------------------------------------------------------------------
# Stores
# ---------------------------------------------------------------------------
store_locations = [
    ("Coraopolis Main St",   "Coraopolis", "PA", "Northeast"),
    ("Pittsburgh Downtown",  "Pittsburgh", "PA", "Northeast"),
    ("Pittsburgh East End",  "Pittsburgh", "PA", "Northeast"),
    ("Robinson Town Center", "Pittsburgh", "PA", "Northeast"),
    ("Erie Plaza",           "Erie",       "PA", "Northeast"),
    ("Harrisburg Square",    "Harrisburg", "PA", "Northeast"),
    ("Buffalo North",        "Buffalo",    "NY", "Northeast"),
    ("Rochester Center",     "Rochester",  "NY", "Northeast"),
    ("Baltimore West",       "Baltimore",  "MD", "Mid-Atlantic"),
    ("Annapolis Plaza",      "Annapolis",  "MD", "Mid-Atlantic"),
    ("Richmond Commons",     "Richmond",   "VA", "Mid-Atlantic"),
    ("Norfolk Crossing",     "Norfolk",    "VA", "Mid-Atlantic"),
    ("Columbus Central",     "Columbus",   "OH", "Midwest"),
    ("Cleveland Heights",    "Cleveland",  "OH", "Midwest"),
    ("Cincinnati Square",    "Cincinnati", "OH", "Midwest"),
    ("Charleston Mall",      "Charleston", "WV", "Midwest"),
    ("Morgantown Plaza",     "Morgantown", "WV", "Midwest"),
    ("Detroit North",        "Detroit",    "MI", "Midwest"),
]

stores = []
base_open = datetime.date(2022, 1, 1)
for i, (name, city, state, region) in enumerate(store_locations, start=1):
    open_date = base_open + datetime.timedelta(days=random.randint(0, 900))
    stores.append((i, name, city, state, region, open_date.isoformat()))

# ---------------------------------------------------------------------------
# Employees
# ---------------------------------------------------------------------------
first_names = ["James","Maria","David","Aisha","Michael","Elena","John","Fatima",
               "Robert","Sofia","Daniel","Layla","Kevin","Grace","Anthony","Nina",
               "Brian","Yasmin","Carlos","Wei","Omar","Priya","Steven","Chloe",
               "Marcus","Amara","Tyler","Jasmine","Nathan","Ruby"]
last_names = ["Smith","Johnson","Garcia","Khan","Brown","Petrova","Davis","Ahmed",
              "Miller","Rossi","Wilson","Hussain","Anderson","Lee","Taylor","Chen",
              "Thomas","Ibrahim","Martinez","Zhang","Hassan","Patel","Clark","Dubois",
              "Jackson","Diallo","White","Ali","Harris","Nguyen"]

roles_pool = ["Sales Rep", "Sales Rep", "Sales Rep", "Assistant Manager", "Store Manager"]

employees = []
emp_id = 1
for store_id, *_ in stores:
    n_emp = random.randint(2, 4)
    for _ in range(n_emp):
        fn, ln = random.choice(first_names), random.choice(last_names)
        hire_date = base_open + datetime.timedelta(days=random.randint(0, 1100))
        # ~12% of employees have since left (termination_date populated)
        term_date = ""
        if random.random() < 0.12:
            term = hire_date + datetime.timedelta(days=random.randint(200, 700))
            if term < datetime.date(2026, 7, 1):
                term_date = term.isoformat()
        role = random.choice(roles_pool)
        employees.append((emp_id, f"{fn} {ln}", store_id, role, hire_date.isoformat(), term_date))
        emp_id += 1

# ---------------------------------------------------------------------------
# Customers
# ---------------------------------------------------------------------------
cust_states = ["PA", "NY", "MD", "VA", "OH", "WV", "MI"]
n_customers = 2600
customers = []
for cid in range(1, n_customers + 1):
    fn, ln = random.choice(first_names), random.choice(last_names)
    signup = datetime.date(2025, 1, 1) + datetime.timedelta(days=random.randint(0, 545))
    state = random.choice(cust_states)
    # ~3% missing state (data-quality gap, e.g. not captured at signup)
    if random.random() < 0.03:
        state = ""
    customers.append((cid, f"{fn} {ln}", state, signup.isoformat()))

# ---------------------------------------------------------------------------
# Transactions
# ---------------------------------------------------------------------------
txn_types = ["New Activation", "Upgrade", "Plan Change", "Accessory Sale", "Bill Payment"]
txn_weights = [0.12, 0.08, 0.06, 0.14, 0.60]  # bill payment dominates (recurring monthly)
statuses = ["Completed", "Completed", "Completed", "Completed", "Completed",
            "Completed", "Completed", "Completed", "Refunded", "Voided"]

plan_price = {p[0]: p[2] for p in plans}

start_date = datetime.date(2025, 1, 1)
end_date = datetime.date(2026, 6, 30)
n_days = (end_date - start_date).days

# store "strength" multipliers so some stores realistically outperform others
store_strength = {s[0]: random.uniform(0.6, 1.6) for s in stores}

transactions = []
tid = 1
target_n = 10500
active_employees_by_store = {}
for e in employees:
    active_employees_by_store.setdefault(e[2], []).append(e)

while tid <= target_n:
    store_id = random.choices(
        [s[0] for s in stores],
        weights=[store_strength[s[0]] for s in stores],
        k=1,
    )[0]
    txn_date = start_date + datetime.timedelta(days=random.randint(0, n_days))
    emp_pool = active_employees_by_store[store_id]
    # pick an employee who was actually hired by that date (approx realism)
    valid_emps = [e for e in emp_pool if e[4] <= txn_date.isoformat()]
    if not valid_emps:
        valid_emps = emp_pool
    employee_id = random.choice(valid_emps)[0]
    # ~5% of transactions are self-service (no employee attached)
    if random.random() < 0.05:
        employee_id = ""

    customer_id = random.randint(1, n_customers)
    ttype = random.choices(txn_types, weights=txn_weights, k=1)[0]
    status = random.choices(statuses, k=1)[0]

    if ttype in ("New Activation", "Upgrade", "Plan Change", "Bill Payment"):
        plan_id = random.randint(1, len(plans))
        base = plan_price[plan_id]
        if ttype == "New Activation":
            amount = round(base + random.uniform(5, 15), 2)  # + activation fee
        elif ttype == "Upgrade":
            amount = round(base + random.uniform(20, 80), 2)  # + device fee
        elif ttype == "Plan Change":
            amount = round(random.uniform(0, 10), 2)  # small/no fee
        else:  # Bill Payment
            amount = base
    else:  # Accessory Sale
        plan_id = ""
        amount = round(random.uniform(9.99, 149.99), 2)

    if status == "Refunded":
        amount = -abs(amount)
    elif status == "Voided":
        amount = 0.0

    transactions.append((tid, store_id, employee_id, customer_id, plan_id,
                          txn_date.isoformat(), ttype, status, amount))
    tid += 1

# --- inject a small number of duplicate rows (data-quality issue) ---
# Simulates a POS double-submit: the same sale gets logged twice with two
# different transaction_ids but otherwise identical column values. This is
# the realistic failure mode (a true repeated primary key can't be loaded),
# and it's exactly the kind of duplicate a SQL analyst has to catch with a
# GROUP BY / HAVING COUNT(*) > 1 query rather than a naive PK check.
dupes = random.sample(transactions, 40)
transactions.extend(dupes)
random.shuffle(transactions)

final_rows = []
next_id = 1
for row in transactions:
    content = row[1:]  # everything except the original transaction_id
    final_rows.append((next_id,) + content)
    next_id += 1

transactions = final_rows

# ---------------------------------------------------------------------------
# Write CSVs
# ---------------------------------------------------------------------------
def write_csv(filename, header, rows):
    path = os.path.join(OUT_DIR, filename)
    with open(path, "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(header)
        w.writerows(rows)
    print(f"wrote {path} ({len(rows)} rows)")

write_csv("plans.csv", ["plan_id", "plan_name", "monthly_price", "data_allowance_gb", "plan_type"], plans)
write_csv("stores.csv", ["store_id", "store_name", "city", "state", "region", "open_date"], stores)
write_csv("employees.csv", ["employee_id", "employee_name", "store_id", "role", "hire_date", "termination_date"], employees)
write_csv("customers.csv", ["customer_id", "customer_name", "state", "signup_date"], customers)
write_csv("transactions.csv", ["transaction_id", "store_id", "employee_id", "customer_id", "plan_id",
                                "transaction_date", "transaction_type", "status", "amount"], transactions)

print("\nSummary:")
print(f"  stores: {len(stores)}")
print(f"  employees: {len(employees)}")
print(f"  customers: {len(customers)}")
print(f"  transactions (incl. {len(dupes)} intentional dupes): {len(transactions)}")
