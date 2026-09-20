-- ============================================================================
-- Telecom Retail Store Performance Analysis
-- Schema definition
-- ============================================================================
-- Models a Cricket Wireless-style prepaid retail chain: multiple stores
-- across several states, employees assigned to stores, customers, a small
-- catalog of prepaid plans, and the transactions (activations, upgrades,
-- plan changes, accessory sales, and recurring bill payments) that tie
-- everything together.

DROP DATABASE IF EXISTS telecom_retail;
CREATE DATABASE telecom_retail;
USE telecom_retail;

-- ---------------------------------------------------------------------------
-- plans: catalog of prepaid plans offered
-- ---------------------------------------------------------------------------
CREATE TABLE plans (
    plan_id            INT PRIMARY KEY,
    plan_name          VARCHAR(50)    NOT NULL,
    monthly_price      DECIMAL(6,2)   NOT NULL,
    data_allowance_gb  INT            NOT NULL,
    plan_type          VARCHAR(20)    NOT NULL
);

-- ---------------------------------------------------------------------------
-- stores: retail storefronts
-- ---------------------------------------------------------------------------
CREATE TABLE stores (
    store_id     INT PRIMARY KEY,
    store_name   VARCHAR(100) NOT NULL,
    city         VARCHAR(50)  NOT NULL,
    state        VARCHAR(2)   NOT NULL,
    region       VARCHAR(30)  NOT NULL,
    open_date    DATE         NOT NULL
);

-- ---------------------------------------------------------------------------
-- employees: sales reps and managers, each assigned to one store
-- ---------------------------------------------------------------------------
CREATE TABLE employees (
    employee_id      INT PRIMARY KEY,
    employee_name    VARCHAR(100) NOT NULL,
    store_id         INT          NOT NULL,
    role             VARCHAR(30)  NOT NULL,
    hire_date        DATE         NOT NULL,
    termination_date DATE         NULL,          -- NULL = still employed
    CONSTRAINT fk_employees_store
        FOREIGN KEY (store_id) REFERENCES stores(store_id)
);

-- ---------------------------------------------------------------------------
-- customers
-- ---------------------------------------------------------------------------
CREATE TABLE customers (
    customer_id   INT PRIMARY KEY,
    customer_name VARCHAR(100) NOT NULL,
    state         VARCHAR(2)   NULL,              -- a few rows missing at signup
    signup_date   DATE         NOT NULL
);

-- ---------------------------------------------------------------------------
-- transactions: every activation, upgrade, plan change, accessory sale, and
-- bill payment recorded at the point of sale
-- ---------------------------------------------------------------------------
CREATE TABLE transactions (
    transaction_id   INT PRIMARY KEY,
    store_id         INT           NOT NULL,
    employee_id      INT           NULL,          -- NULL = self-service / kiosk
    customer_id      INT           NOT NULL,
    plan_id          INT           NULL,           -- NULL for accessory-only sales
    transaction_date DATE          NOT NULL,
    transaction_type VARCHAR(20)   NOT NULL,       -- New Activation, Upgrade, Plan Change, Accessory Sale, Bill Payment
    status           VARCHAR(20)   NOT NULL,       -- Completed, Refunded, Voided
    amount           DECIMAL(8,2)  NOT NULL,
    CONSTRAINT fk_transactions_store
        FOREIGN KEY (store_id) REFERENCES stores(store_id),
    CONSTRAINT fk_transactions_employee
        FOREIGN KEY (employee_id) REFERENCES employees(employee_id),
    CONSTRAINT fk_transactions_customer
        FOREIGN KEY (customer_id) REFERENCES customers(customer_id),
    CONSTRAINT fk_transactions_plan
        FOREIGN KEY (plan_id) REFERENCES plans(plan_id)
);

CREATE INDEX idx_transactions_store_date ON transactions(store_id, transaction_date);
CREATE INDEX idx_transactions_customer   ON transactions(customer_id);
CREATE INDEX idx_transactions_employee   ON transactions(employee_id);
