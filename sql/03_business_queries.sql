-- =====================================================================
-- Business Analysis SQL — Ecommerce Growth Analytics
-- =====================================================================
-- 25 curated queries answering real business questions, grouped by
-- domain. Each query is written to run directly against the raw_*
-- tables loaded in Step 2 (no cleaning applied yet — see Python notebook
-- for the cleaned/feature-engineered layer used in deeper analysis).
-- =====================================================================
USE ecommerce_analytics;

-- ---------------------------------------------------------------------
-- REVENUE & GROWTH
-- ---------------------------------------------------------------------

-- Q1. Monthly revenue trend
SELECT DATE_FORMAT(order_date, '%Y-%m') AS month,
       ROUND(SUM(order_value), 2) AS revenue,
       COUNT(*) AS orders
FROM raw_orders
WHERE status = 'Completed'
GROUP BY month
ORDER BY month;

-- Q2. Month-over-month revenue growth rate
WITH monthly AS (
  SELECT DATE_FORMAT(order_date, '%Y-%m') AS month, SUM(order_value) AS revenue
  FROM raw_orders WHERE status = 'Completed'
  GROUP BY month
)
SELECT month, revenue,
       ROUND(100 * (revenue - LAG(revenue) OVER (ORDER BY month)) /
             LAG(revenue) OVER (ORDER BY month), 2) AS mom_growth_pct
FROM monthly ORDER BY month;

-- Q3. Revenue by country
SELECT c.country, ROUND(SUM(o.order_value), 2) AS revenue, COUNT(*) AS orders
FROM raw_orders o JOIN raw_customers c ON o.customer_id = c.customer_id
WHERE o.status = 'Completed'
GROUP BY c.country ORDER BY revenue DESC;

-- Q4. Average order value (AOV) trend by month
SELECT DATE_FORMAT(order_date, '%Y-%m') AS month, ROUND(AVG(order_value), 2) AS aov
FROM raw_orders WHERE status = 'Completed'
GROUP BY month ORDER BY month;

-- Q5. Revenue lost to returns (gross vs net revenue)
SELECT
  ROUND(SUM(o.order_value), 2) AS gross_revenue,
  ROUND(SUM(CASE WHEN o.status = 'Returned' THEN o.order_value ELSE 0 END), 2) AS returned_revenue,
  ROUND(SUM(CASE WHEN o.status = 'Completed' THEN o.order_value ELSE 0 END), 2) AS net_revenue
FROM raw_orders o;

-- ---------------------------------------------------------------------
-- CUSTOMER VALUE & SEGMENTATION
-- ---------------------------------------------------------------------

-- Q6. Top 20 customers by lifetime spend
SELECT c.customer_id, c.country, ROUND(SUM(o.order_value), 2) AS lifetime_value,
       COUNT(o.order_id) AS total_orders
FROM raw_customers c JOIN raw_orders o ON c.customer_id = o.customer_id
WHERE o.status = 'Completed'
GROUP BY c.customer_id, c.country
ORDER BY lifetime_value DESC LIMIT 20;

-- Q7. Customer Lifetime Value (CLV) by acquisition source
SELECT c.acquisition_source,
       COUNT(DISTINCT c.customer_id) AS customers,
       ROUND(SUM(o.order_value) / COUNT(DISTINCT c.customer_id), 2) AS avg_clv
FROM raw_customers c LEFT JOIN raw_orders o
  ON c.customer_id = o.customer_id AND o.status = 'Completed'
GROUP BY c.acquisition_source ORDER BY avg_clv DESC;

-- Q8. RFM-style segmentation: Recency, Frequency, Monetary per customer
SELECT
  customer_id,
  DATEDIFF((SELECT MAX(order_date) FROM raw_orders), MAX(order_date)) AS recency_days,
  COUNT(*) AS frequency,
  ROUND(SUM(order_value), 2) AS monetary
FROM raw_orders
WHERE status = 'Completed'
GROUP BY customer_id
ORDER BY monetary DESC
LIMIT 50;

-- Q9. One-time buyers vs repeat customers
SELECT
  CASE WHEN order_count = 1 THEN 'One-time buyer' ELSE 'Repeat customer' END AS segment,
  COUNT(*) AS customers
FROM (
  SELECT customer_id, COUNT(*) AS order_count
  FROM raw_orders WHERE status = 'Completed'
  GROUP BY customer_id
) t
GROUP BY segment;

-- Q10. Customer age band vs average order value
SELECT
  CASE
    WHEN age < 25 THEN '18-24'
    WHEN age < 35 THEN '25-34'
    WHEN age < 45 THEN '35-44'
    WHEN age < 55 THEN '45-54'
    ELSE '55+'
  END AS age_band,
  ROUND(AVG(o.order_value), 2) AS avg_order_value,
  COUNT(*) AS orders
FROM raw_customers c JOIN raw_orders o ON c.customer_id = o.customer_id
WHERE o.status = 'Completed'
GROUP BY age_band ORDER BY age_band;

-- Q11. New customers acquired per month (signup cohort size)
SELECT DATE_FORMAT(signup_date, '%Y-%m') AS cohort_month, COUNT(*) AS new_customers
FROM raw_customers
GROUP BY cohort_month ORDER BY cohort_month;

-- ---------------------------------------------------------------------
-- MARKETING PERFORMANCE
-- ---------------------------------------------------------------------

-- Q12. Revenue and order count by marketing channel
SELECT cam.channel,
       ROUND(SUM(o.order_value), 2) AS revenue,
       COUNT(*) AS orders
FROM raw_orders o JOIN raw_campaigns cam ON o.campaign_id = cam.campaign_id
WHERE o.status = 'Completed'
GROUP BY cam.channel ORDER BY revenue DESC;

-- Q13. Return on Ad Spend (ROAS) per campaign
SELECT cam.campaign_name, cam.channel, cam.budget,
       ROUND(SUM(o.order_value), 2) AS revenue,
       ROUND(SUM(o.order_value) / cam.budget, 2) AS roas
FROM raw_campaigns cam
LEFT JOIN raw_orders o ON cam.campaign_id = o.campaign_id AND o.status = 'Completed'
GROUP BY cam.campaign_id, cam.campaign_name, cam.channel, cam.budget
ORDER BY roas DESC;

-- Q14. Customer Acquisition Cost (CAC) per channel
-- (approximation: campaign budget / number of distinct customers first acquired via that channel's campaigns)
SELECT cam.channel,
       ROUND(SUM(cam.budget), 2) AS total_budget,
       COUNT(DISTINCT o.customer_id) AS customers_acquired,
       ROUND(SUM(cam.budget) / COUNT(DISTINCT o.customer_id), 2) AS approx_cac
FROM raw_campaigns cam
JOIN raw_orders o ON cam.campaign_id = o.campaign_id
GROUP BY cam.channel ORDER BY approx_cac ASC;

-- Q15. Underperforming campaigns (ROAS below 1 = losing money)
SELECT cam.campaign_name, cam.channel, cam.budget,
       ROUND(COALESCE(SUM(o.order_value), 0), 2) AS revenue,
       ROUND(COALESCE(SUM(o.order_value), 0) / cam.budget, 2) AS roas
FROM raw_campaigns cam
LEFT JOIN raw_orders o ON cam.campaign_id = o.campaign_id AND o.status = 'Completed'
GROUP BY cam.campaign_id, cam.campaign_name, cam.channel, cam.budget
HAVING roas < 1
ORDER BY roas ASC;

-- ---------------------------------------------------------------------
-- PRODUCT & INVENTORY
-- ---------------------------------------------------------------------

-- Q16. Top 10 products by revenue
-- NOTE: final_price in this dataset is a PER-UNIT price after discount, not a line total.
-- Line revenue is therefore final_price * quantity (verified against products.csv cost/price).
SELECT p.sku, p.category, ROUND(SUM(oi.final_price * oi.quantity), 2) AS revenue,
       SUM(oi.quantity) AS units_sold
FROM raw_order_items oi JOIN raw_products p ON oi.product_id = p.product_id
GROUP BY p.product_id, p.sku, p.category
ORDER BY revenue DESC LIMIT 10;

-- Q17. Revenue and margin by product category
SELECT p.category,
       ROUND(SUM(oi.final_price * oi.quantity), 2) AS revenue,
       ROUND(SUM(oi.quantity * p.cost), 2) AS total_cost,
       ROUND(SUM(oi.final_price * oi.quantity) - SUM(oi.quantity * p.cost), 2) AS gross_profit,
       ROUND(100 * (SUM(oi.final_price * oi.quantity) - SUM(oi.quantity * p.cost)) / SUM(oi.final_price * oi.quantity), 2) AS margin_pct
FROM raw_order_items oi JOIN raw_products p ON oi.product_id = p.product_id
GROUP BY p.category ORDER BY gross_profit DESC;

-- Q18. Products with the highest return rate
SELECT p.sku, p.category,
       COUNT(DISTINCT oi.order_id) AS total_orders_containing_product,
       COUNT(DISTINCT r.order_id) AS returned_orders,
       ROUND(100 * COUNT(DISTINCT r.order_id) / COUNT(DISTINCT oi.order_id), 2) AS return_rate_pct
FROM raw_order_items oi
JOIN raw_products p ON oi.product_id = p.product_id
LEFT JOIN raw_returns r ON oi.order_id = r.order_id
GROUP BY p.product_id, p.sku, p.category
HAVING total_orders_containing_product > 20
ORDER BY return_rate_pct DESC LIMIT 15;

-- Q19. Average discount given by category
SELECT p.category, ROUND(AVG(oi.discount_pct), 2) AS avg_discount_pct,
       ROUND(SUM(oi.quantity * (oi.unit_price - oi.final_price)), 2) AS total_discount_value
FROM raw_order_items oi JOIN raw_products p ON oi.product_id = p.product_id
GROUP BY p.category ORDER BY total_discount_value DESC;

-- Q20. Basket size — average number of distinct products per order
SELECT ROUND(AVG(item_count), 2) AS avg_items_per_order
FROM (SELECT order_id, COUNT(*) AS item_count FROM raw_order_items GROUP BY order_id) t;

-- ---------------------------------------------------------------------
-- RETURNS ANALYSIS
-- ---------------------------------------------------------------------

-- Q21. Return reasons breakdown
SELECT return_reason, COUNT(*) AS occurrences,
       ROUND(100 * COUNT(*) / (SELECT COUNT(*) FROM raw_returns), 2) AS pct_of_returns
FROM raw_returns
GROUP BY return_reason ORDER BY occurrences DESC;

-- Q22. Return rate by country
SELECT c.country,
       COUNT(DISTINCT o.order_id) AS total_orders,
       COUNT(DISTINCT r.order_id) AS returned_orders,
       ROUND(100 * COUNT(DISTINCT r.order_id) / COUNT(DISTINCT o.order_id), 2) AS return_rate_pct
FROM raw_orders o
JOIN raw_customers c ON o.customer_id = c.customer_id
LEFT JOIN raw_returns r ON o.order_id = r.order_id
GROUP BY c.country ORDER BY return_rate_pct DESC;

-- ---------------------------------------------------------------------
-- EXECUTIVE KPIs
-- ---------------------------------------------------------------------

-- Q23. Headline KPI summary (single-row executive snapshot)
SELECT
  (SELECT ROUND(SUM(order_value), 2) FROM raw_orders WHERE status = 'Completed') AS net_revenue,
  (SELECT COUNT(*) FROM raw_orders) AS total_orders,
  (SELECT ROUND(AVG(order_value), 2) FROM raw_orders WHERE status = 'Completed') AS aov,
  (SELECT COUNT(DISTINCT customer_id) FROM raw_orders) AS active_customers,
  (SELECT ROUND(100 * COUNT(*) / (SELECT COUNT(*) FROM raw_orders), 2) FROM raw_orders WHERE status = 'Returned') AS return_rate_pct;

-- Q24. Payment method distribution
SELECT payment_method, COUNT(*) AS txns, ROUND(SUM(amount), 2) AS total_amount
FROM raw_payments GROUP BY payment_method ORDER BY total_amount DESC;

-- Q25. Cross-check: does our computed daily revenue match the provided KPI snapshot?
SELECT k.kpi_date, k.revenue AS reported_revenue,
       ROUND(o.computed_revenue, 2) AS computed_revenue,
       ROUND(k.revenue - o.computed_revenue, 2) AS diff
FROM raw_daily_kpi_snapshot k
LEFT JOIN (
  SELECT order_date, SUM(order_value) AS computed_revenue
  FROM raw_orders WHERE status = 'Completed' GROUP BY order_date
) o ON k.kpi_date = o.order_date
ORDER BY ABS(k.revenue - o.computed_revenue) DESC
LIMIT 10;
