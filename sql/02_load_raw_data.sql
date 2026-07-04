-- =====================================================================
-- Load raw CSV files into MySQL raw tables (respects FK dependency order)
-- =====================================================================
USE ecommerce_analytics;

SET FOREIGN_KEY_CHECKS = 0;  -- allow flexible load order, re-enabled at end

-- 1. Independent dimension tables first
LOAD DATA LOCAL INFILE '/home/claude/Ecommerce-Growth-Analytics/data/raw/customers.csv'
INTO TABLE raw_customers
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(customer_id, signup_date, age, gender, country, city, acquisition_source);

LOAD DATA LOCAL INFILE '/home/claude/Ecommerce-Growth-Analytics/data/raw/products.csv'
INTO TABLE raw_products
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(product_id, sku, category, cost, price);

LOAD DATA LOCAL INFILE '/home/claude/Ecommerce-Growth-Analytics/data/raw/campaigns.csv'
INTO TABLE raw_campaigns
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(campaign_id, campaign_name, channel, budget);

-- 2. Orders (depends on customers, campaigns)
LOAD DATA LOCAL INFILE '/home/claude/Ecommerce-Growth-Analytics/data/raw/orders.csv'
INTO TABLE raw_orders
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(order_id, customer_id, order_date, campaign_id, order_value, status);

-- 3. Tables that depend on orders
LOAD DATA LOCAL INFILE '/home/claude/Ecommerce-Growth-Analytics/data/raw/order_items.csv'
INTO TABLE raw_order_items
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(order_id, product_id, quantity, unit_price, discount_pct, final_price);

LOAD DATA LOCAL INFILE '/home/claude/Ecommerce-Growth-Analytics/data/raw/payments.csv'
INTO TABLE raw_payments
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(order_id, payment_method, amount);

LOAD DATA LOCAL INFILE '/home/claude/Ecommerce-Growth-Analytics/data/raw/returns.csv'
INTO TABLE raw_returns
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(order_id, return_reason);

-- 4. Standalone KPI snapshot table
LOAD DATA LOCAL INFILE '/home/claude/Ecommerce-Growth-Analytics/data/raw/daily_kpi_snapshot.csv'
INTO TABLE raw_daily_kpi_snapshot
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(kpi_date, revenue, marketing_spend, roas, orders, cac);

SET FOREIGN_KEY_CHECKS = 1;

-- Row count verification
SELECT 'raw_customers' AS tbl, COUNT(*) AS row_count FROM raw_customers
UNION ALL SELECT 'raw_products', COUNT(*) FROM raw_products
UNION ALL SELECT 'raw_campaigns', COUNT(*) FROM raw_campaigns
UNION ALL SELECT 'raw_orders', COUNT(*) FROM raw_orders
UNION ALL SELECT 'raw_order_items', COUNT(*) FROM raw_order_items
UNION ALL SELECT 'raw_payments', COUNT(*) FROM raw_payments
UNION ALL SELECT 'raw_returns', COUNT(*) FROM raw_returns
UNION ALL SELECT 'raw_daily_kpi_snapshot', COUNT(*) FROM raw_daily_kpi_snapshot;
