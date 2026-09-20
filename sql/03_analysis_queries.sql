-- ============================================================================
-- Telecom Retail Store Performance Analysis
-- Analysis queries
-- ============================================================================
-- Run 01_schema.sql and 02_load_data.sql first. Every query below has been
-- run end-to-end against a live MySQL 8.0 instance loaded with this project's
-- data.
--
-- Sections:
--   1. Data cleaning & quality checks
--   2. Store & regional performance
--   3. Employee performance
--   4. Customers & plans

USE telecom_retail;

-- ============================================================================
-- SECTION 1: DATA CLEANING & QUALITY CHECKS
-- ============================================================================

-- Q1. Find duplicate transactions (same store/employee/customer/plan/date/
--     type/status/amount logged more than once -- a POS double-submit).
SELECT
    store_id, employee_id, customer_id, plan_id, transaction_date,
    transaction_type, status, amount,
    COUNT(*) AS times_logged,
    GROUP_CONCAT(transaction_id ORDER BY transaction_id) AS transaction_ids
FROM transactions
GROUP BY store_id, employee_id, customer_id, plan_id, transaction_date,
         transaction_type, status, amount
HAVING COUNT(*) > 1
ORDER BY times_logged DESC;

-- Q2. Data completeness check: how many rows are missing each nullable
--     field, and what that missingness actually means for the business.
--     (employee_id NULL = self-service/kiosk sale, which is expected;
--      plan_id NULL = accessory-only sale, also expected;
--      customers.state NULL = a real data-capture gap worth flagging.)
SELECT
    (SELECT COUNT(*) FROM transactions WHERE employee_id IS NULL) AS self_service_transactions,
    (SELECT COUNT(*) FROM transactions WHERE plan_id IS NULL)     AS accessory_only_transactions,
    (SELECT COUNT(*) FROM customers WHERE state IS NULL)          AS customers_missing_state,
    (SELECT COUNT(*) FROM customers)                              AS total_customers;

-- Q3. Reusable "clean" view: one row per real transaction (duplicates
--     collapsed) and Completed status only, since Refunded/Voided rows
--     shouldn't count toward revenue. All revenue queries below build on it.
CREATE OR REPLACE VIEW v_transactions_clean AS
SELECT *
FROM (
    SELECT
        t.*,
        ROW_NUMBER() OVER (
            PARTITION BY store_id, employee_id, customer_id, plan_id,
                         transaction_date, transaction_type, status, amount
            ORDER BY transaction_id
        ) AS rn
    FROM transactions t
) deduped
WHERE rn = 1
  AND status = 'Completed';

-- ============================================================================
-- SECTION 2: STORE & REGIONAL PERFORMANCE
-- ============================================================================

-- Q4. Store leaderboard: revenue, transaction count, and rank company-wide.
SELECT
    s.store_id,
    s.store_name,
    s.region,
    COUNT(*)                       AS transaction_count,
    ROUND(SUM(vc.amount), 2)       AS total_revenue,
    ROUND(AVG(vc.amount), 2)       AS avg_transaction_value,
    RANK() OVER (ORDER BY SUM(vc.amount) DESC) AS revenue_rank
FROM v_transactions_clean vc
JOIN stores s ON s.store_id = vc.store_id
GROUP BY s.store_id, s.store_name, s.region
ORDER BY revenue_rank;

-- Q5. Each store's rank *within its own region*, and how far it sits above
--     or below the regional average -- the "which stores need attention"
--     query a district manager would actually ask for.
WITH store_revenue AS (
    SELECT
        s.store_id, s.store_name, s.region,
        SUM(vc.amount) AS total_revenue
    FROM v_transactions_clean vc
    JOIN stores s ON s.store_id = vc.store_id
    GROUP BY s.store_id, s.store_name, s.region
)
SELECT
    store_id, store_name, region, ROUND(total_revenue, 2) AS total_revenue,
    RANK() OVER (PARTITION BY region ORDER BY total_revenue DESC) AS rank_in_region,
    ROUND(AVG(total_revenue) OVER (PARTITION BY region), 2) AS region_avg_revenue,
    ROUND(total_revenue - AVG(total_revenue) OVER (PARTITION BY region), 2) AS vs_region_avg
FROM store_revenue
ORDER BY region, rank_in_region;

-- Q6. Month-over-month company revenue trend and % growth.
WITH monthly_revenue AS (
    SELECT
        DATE_FORMAT(transaction_date, '%Y-%m') AS month,
        SUM(amount) AS revenue
    FROM v_transactions_clean
    GROUP BY DATE_FORMAT(transaction_date, '%Y-%m')
)
SELECT
    month,
    ROUND(revenue, 2) AS revenue,
    ROUND(LAG(revenue) OVER (ORDER BY month), 2) AS prior_month_revenue,
    ROUND(
        100.0 * (revenue - LAG(revenue) OVER (ORDER BY month))
        / LAG(revenue) OVER (ORDER BY month), 1
    ) AS mom_growth_pct
FROM monthly_revenue
ORDER BY month;

-- Q7. Running (cumulative) revenue per store, month by month -- useful for
--     tracking a store's progress toward an annual target.
WITH store_monthly AS (
    SELECT
        s.store_id, s.store_name,
        DATE_FORMAT(vc.transaction_date, '%Y-%m') AS month,
        SUM(vc.amount) AS monthly_revenue
    FROM v_transactions_clean vc
    JOIN stores s ON s.store_id = vc.store_id
    GROUP BY s.store_id, s.store_name, DATE_FORMAT(vc.transaction_date, '%Y-%m')
)
SELECT
    store_id, store_name, month,
    ROUND(monthly_revenue, 2) AS monthly_revenue,
    ROUND(SUM(monthly_revenue) OVER (
        PARTITION BY store_id ORDER BY month
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ), 2) AS running_total_revenue
FROM store_monthly
ORDER BY store_id, month;

-- ============================================================================
-- SECTION 3: EMPLOYEE PERFORMANCE
-- ============================================================================

-- Q8. Rep leaderboard: revenue and transaction count, ranked company-wide
--     and again within their own store.
SELECT
    e.employee_id, e.employee_name, e.store_id, s.store_name,
    COUNT(*)                 AS transaction_count,
    ROUND(SUM(vc.amount), 2) AS total_revenue,
    RANK() OVER (ORDER BY SUM(vc.amount) DESC) AS company_rank,
    DENSE_RANK() OVER (PARTITION BY e.store_id ORDER BY SUM(vc.amount) DESC) AS rank_in_store
FROM v_transactions_clean vc
JOIN employees e ON e.employee_id = vc.employee_id
JOIN stores s ON s.store_id = e.store_id
GROUP BY e.employee_id, e.employee_name, e.store_id, s.store_name
ORDER BY company_rank;

-- Q9. Top-performing rep at each store (one row per store).
WITH ranked_reps AS (
    SELECT
        e.store_id, s.store_name, e.employee_id, e.employee_name,
        SUM(vc.amount) AS total_revenue,
        ROW_NUMBER() OVER (PARTITION BY e.store_id ORDER BY SUM(vc.amount) DESC) AS rn
    FROM v_transactions_clean vc
    JOIN employees e ON e.employee_id = vc.employee_id
    JOIN stores s ON s.store_id = e.store_id
    GROUP BY e.store_id, s.store_name, e.employee_id, e.employee_name
)
SELECT store_id, store_name, employee_name AS top_rep, ROUND(total_revenue, 2) AS total_revenue
FROM ranked_reps
WHERE rn = 1
ORDER BY store_id;

-- Q10. Currently-employed reps with zero completed sales in the final 90
--      days of data on record -- candidates for coaching or follow-up.
SELECT e.employee_id, e.employee_name, e.store_id, e.hire_date
FROM employees e
WHERE e.termination_date IS NULL
  AND NOT EXISTS (
        SELECT 1
        FROM v_transactions_clean vc
        WHERE vc.employee_id = e.employee_id
          AND vc.transaction_date >= (
                SELECT DATE_SUB(MAX(transaction_date), INTERVAL 90 DAY)
                FROM v_transactions_clean
          )
  )
ORDER BY e.store_id;

-- ============================================================================
-- SECTION 4: CUSTOMERS & PLANS
-- ============================================================================

-- Q11. Plan popularity: activation/upgrade/bill-payment volume and revenue
--      by plan, with each plan's share of total plan revenue.
SELECT
    p.plan_name, p.monthly_price,
    COUNT(*) AS transaction_count,
    ROUND(SUM(vc.amount), 2) AS plan_revenue,
    ROUND(100.0 * SUM(vc.amount) / SUM(SUM(vc.amount)) OVER (), 1) AS pct_of_plan_revenue
FROM v_transactions_clean vc
JOIN plans p ON p.plan_id = vc.plan_id
GROUP BY p.plan_name, p.monthly_price
ORDER BY plan_revenue DESC;

-- Q12. Customer value tiers: bucket each customer by total completed
--      spend so marketing can target the "High" tier differently from
--      one-time "Low" spenders.
WITH customer_spend AS (
    SELECT customer_id, SUM(amount) AS total_spend
    FROM v_transactions_clean
    GROUP BY customer_id
)
SELECT
    CASE
        WHEN total_spend >= 300 THEN 'High'
        WHEN total_spend >= 100 THEN 'Medium'
        ELSE 'Low'
    END AS value_tier,
    COUNT(*) AS customer_count,
    ROUND(AVG(total_spend), 2) AS avg_spend_in_tier,
    ROUND(SUM(total_spend), 2) AS tier_total_revenue
FROM customer_spend
GROUP BY value_tier
ORDER BY tier_total_revenue DESC;

-- Q13. Data-quality note: what share of the customer base is missing a
--      state, since that blocks any region-level marketing for them.
SELECT
    COUNT(*) AS customers_missing_state,
    (SELECT COUNT(*) FROM customers) AS total_customers,
    ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM customers), 1) AS pct_missing
FROM customers
WHERE state IS NULL;
