-- =====================================================================
-- Ecommerce Growth Analytics — Raw Schema DDL (MySQL 8.0)
-- =====================================================================
-- Purpose : Create the raw ("landing") layer tables exactly matching the
--           source CSV structure. No transformations happen here — this
--           layer exists purely to get data into a queryable database.
-- Author  : Isfaque | Data Analyst Portfolio Project
-- =====================================================================

CREATE DATABASE IF NOT EXISTS ecommerce_analytics CHARACTER SET utf8mb4;
USE ecommerce_analytics;

-- ---------------------------------------------------------------------
-- dim-like source table: customers
-- One row per customer. customer_id is the natural primary key coming
-- from the source system, so we keep it as INT PK rather than adding a
-- surrogate key at the raw layer (surrogate keys get added later in the
-- dbt/analytics layer, not here).
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS raw_customers;
CREATE TABLE raw_customers (
    customer_id         INT PRIMARY KEY,        -- natural key from source system
    signup_date          DATE,                    -- used for cohort & tenure analysis
    age                   SMALLINT,                -- small range (0-120) -> SMALLINT saves space vs INT
    gender                VARCHAR(20),
    country               VARCHAR(60),
    city                  VARCHAR(60),
    acquisition_source    VARCHAR(30)              -- e.g. Paid / Organic / Referral
) ENGINE=InnoDB;

-- Index rationale: country and acquisition_source are the two columns
-- most frequently filtered/grouped on in marketing & geo analysis.
CREATE INDEX idx_customers_country ON raw_customers(country);
CREATE INDEX idx_customers_acq_source ON raw_customers(acquisition_source);

-- ---------------------------------------------------------------------
-- products
-- One row per SKU. price/cost as DECIMAL, not FLOAT, because money
-- values must never suffer floating-point rounding drift.
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS raw_products;
CREATE TABLE raw_products (
    product_id    INT PRIMARY KEY,
    sku            VARCHAR(20) UNIQUE,             -- business identifier, also unique
    category       VARCHAR(50),
    cost           DECIMAL(10,2),                   -- what it costs the business
    price          DECIMAL(10,2)                    -- what the customer pays
) ENGINE=InnoDB;

CREATE INDEX idx_products_category ON raw_products(category);

-- ---------------------------------------------------------------------
-- campaigns
-- Small dimension table describing marketing campaigns.
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS raw_campaigns;
CREATE TABLE raw_campaigns (
    campaign_id     INT PRIMARY KEY,
    campaign_name    VARCHAR(100),
    channel          VARCHAR(30),                   -- Google / Meta / Organic / Email etc.
    budget           DECIMAL(12,2)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- orders
-- One row per order — the transactional spine of the whole model.
-- FKs point to customers and campaigns. order_date is indexed because
-- almost every business question filters or groups by time.
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS raw_orders;
CREATE TABLE raw_orders (
    order_id      INT PRIMARY KEY,
    customer_id    INT NOT NULL,
    order_date     DATE NOT NULL,
    campaign_id    INT NULL,                        -- NULL is possible for organic/direct orders
    order_value    DECIMAL(12,2),
    status         VARCHAR(20),                      -- Completed / Cancelled / Pending etc.
    CONSTRAINT fk_orders_customer FOREIGN KEY (customer_id)
        REFERENCES raw_customers(customer_id),
    CONSTRAINT fk_orders_campaign FOREIGN KEY (campaign_id)
        REFERENCES raw_campaigns(campaign_id)
) ENGINE=InnoDB;

CREATE INDEX idx_orders_date ON raw_orders(order_date);
CREATE INDEX idx_orders_status ON raw_orders(status);
CREATE INDEX idx_orders_customer ON raw_orders(customer_id);

-- ---------------------------------------------------------------------
-- order_items
-- One row per line item within an order (grain = order x product).
-- Composite natural key candidate is (order_id, product_id), but since
-- the same product could theoretically appear twice in one order at
-- different discount tiers, we use a surrogate AUTO_INCREMENT PK and
-- add a non-unique composite index instead of a composite PK.
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS raw_order_items;
CREATE TABLE raw_order_items (
    order_item_id   INT AUTO_INCREMENT PRIMARY KEY,  -- surrogate key, source has none
    order_id         INT NOT NULL,
    product_id       INT NOT NULL,
    quantity         INT,
    unit_price       DECIMAL(10,2),
    discount_pct     DECIMAL(5,2),
    final_price      DECIMAL(10,2),
    CONSTRAINT fk_items_order FOREIGN KEY (order_id)
        REFERENCES raw_orders(order_id),
    CONSTRAINT fk_items_product FOREIGN KEY (product_id)
        REFERENCES raw_products(product_id)
) ENGINE=InnoDB;

CREATE INDEX idx_items_order ON raw_order_items(order_id);
CREATE INDEX idx_items_product ON raw_order_items(product_id);

-- ---------------------------------------------------------------------
-- payments
-- One row per order (1:1 with orders in this dataset).
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS raw_payments;
CREATE TABLE raw_payments (
    order_id         INT PRIMARY KEY,                -- 1:1 with orders -> order_id is PK here too
    payment_method    VARCHAR(30),
    amount            DECIMAL(12,2),
    CONSTRAINT fk_payments_order FOREIGN KEY (order_id)
        REFERENCES raw_orders(order_id)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- returns
-- One row per returned order. Not every order appears here.
-- We do NOT enforce uniqueness on order_id until Step "Data Quality"
-- confirms whether any order has more than one return row.
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS raw_returns;
CREATE TABLE raw_returns (
    return_id      INT AUTO_INCREMENT PRIMARY KEY,   -- surrogate, in case of duplicate order_ids
    order_id        INT NOT NULL,
    return_reason    VARCHAR(50),
    CONSTRAINT fk_returns_order FOREIGN KEY (order_id)
        REFERENCES raw_orders(order_id)
) ENGINE=InnoDB;

CREATE INDEX idx_returns_order ON raw_returns(order_id);

-- ---------------------------------------------------------------------
-- daily_kpi_snapshot
-- Pre-aggregated daily rollup — NOT a transactional table. Kept
-- separate from the star schema fact tables; used later purely to
-- validate that our own aggregations from fact_orders / fact_order_items
-- match what the business already reports.
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS raw_daily_kpi_snapshot;
CREATE TABLE raw_daily_kpi_snapshot (
    kpi_date          DATE PRIMARY KEY,
    revenue            DECIMAL(14,2),
    marketing_spend    DECIMAL(14,2),
    roas               DECIMAL(6,2),
    orders             INT,
    cac                DECIMAL(10,2)
) ENGINE=InnoDB;
