-- ============================================================================
-- Telecom Retail Store Performance Analysis
-- Data loading script
-- ============================================================================
-- Loads the CSVs in /data into the schema created by 01_schema.sql.
--
-- If you're using MySQL Workbench: Server > Data Import, or run this file
-- directly with the mysql CLI from the project root, e.g.:
--   mysql --local-infile=1 -u root -p telecom_retail < sql/02_load_data.sql
--
-- local_infile must be enabled on the server for LOAD DATA LOCAL INFILE:
--   SET GLOBAL local_infile = 1;
-- (already handled for you if you're running through the mysql CLI flag above)

USE telecom_retail;

SET FOREIGN_KEY_CHECKS = 0;

-- plans -----------------------------------------------------------------
LOAD DATA LOCAL INFILE 'data/plans.csv'
INTO TABLE plans
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(plan_id, plan_name, monthly_price, data_allowance_gb, plan_type);

-- stores ------------------------------------------------------------------
LOAD DATA LOCAL INFILE 'data/stores.csv'
INTO TABLE stores
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(store_id, store_name, city, state, region, open_date);

-- employees (termination_date can be blank -> NULL) ------------------------
LOAD DATA LOCAL INFILE 'data/employees.csv'
INTO TABLE employees
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(employee_id, employee_name, store_id, role, hire_date, @termination_date)
SET termination_date = NULLIF(@termination_date, '');

-- customers (state can be blank -> NULL) -----------------------------------
LOAD DATA LOCAL INFILE 'data/customers.csv'
INTO TABLE customers
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(customer_id, customer_name, @state, signup_date)
SET state = NULLIF(@state, '');

-- transactions (employee_id and plan_id can be blank -> NULL) --------------
LOAD DATA LOCAL INFILE 'data/transactions.csv'
INTO TABLE transactions
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(transaction_id, store_id, @employee_id, customer_id, @plan_id,
 transaction_date, transaction_type, status, amount)
SET
    employee_id = NULLIF(@employee_id, ''),
    plan_id     = NULLIF(@plan_id, '');

SET FOREIGN_KEY_CHECKS = 1;

-- Quick sanity check
SELECT
    (SELECT COUNT(*) FROM plans)        AS plans_loaded,
    (SELECT COUNT(*) FROM stores)       AS stores_loaded,
    (SELECT COUNT(*) FROM employees)    AS employees_loaded,
    (SELECT COUNT(*) FROM customers)    AS customers_loaded,
    (SELECT COUNT(*) FROM transactions) AS transactions_loaded;
