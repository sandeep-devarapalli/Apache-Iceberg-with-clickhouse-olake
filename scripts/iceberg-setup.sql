-- Complete Iceberg Setup Script
-- 
-- This is a master script that combines all three steps.
-- For step-by-step execution and verification, run the individual scripts:
--
--   Step 1: Query Raw Tables
--     docker exec -it clickhouse-client clickhouse-client --host clickhouse --queries-file /scripts/iceberg-query-raw.sql
--
--   Step 2: Create Silver Layer (Iceberg in MinIO)
--     docker exec -it clickhouse-client clickhouse-client --host clickhouse --queries-file /scripts/iceberg-create-silver.sql
--
--   Step 3: Create Gold Layer (Pre-aggregated KPIs)
--     docker exec -it clickhouse-client clickhouse-client --host clickhouse --queries-file /scripts/iceberg-create-gold.sql
--
-- Or run this complete script to execute all steps at once:
--     docker exec -it clickhouse-client clickhouse-client --host clickhouse --queries-file /scripts/iceberg-setup.sql

-- Enable experimental Iceberg features
SET allow_experimental_database_iceberg = 1;
SET allow_experimental_insert_into_iceberg = 1;
SET use_iceberg_partition_pruning = 1;
SET use_iceberg_metadata_files_cache = 1;

-- ============================================================================
-- STEP 1: Query Raw Iceberg Tables
-- ============================================================================
SELECT '=== STEP 1: Querying Raw Iceberg Tables ===' AS info;

DROP DATABASE IF EXISTS demo_lakehouse_db;
CREATE DATABASE demo_lakehouse_db
ENGINE = DataLakeCatalog('http://iceberg-rest:8181/v1', 'admin', 'password')
SETTINGS 
    catalog_type = 'rest', 
    storage_endpoint = 'http://minio:9090/warehouse', 
    warehouse = 'iceberg_job_demo_db';

USE demo_lakehouse_db;
SELECT 'Available tables:' AS info;
SHOW TABLES;

SELECT 'Iceberg users rows' AS metric, COUNT(*) AS value FROM `iceberg_job_demo_db.users`;
SELECT 'Iceberg products rows' AS metric, COUNT(*) AS value FROM `iceberg_job_demo_db.products`;
SELECT 'Iceberg orders rows' AS metric, COUNT(*) AS value FROM `iceberg_job_demo_db.orders`;
SELECT 'Iceberg user_sessions rows' AS metric, COUNT(*) AS value FROM `iceberg_job_demo_db.user_sessions`;

-- ============================================================================
-- STEP 2: Create Silver Layer (Iceberg in MinIO)
-- ============================================================================
SELECT '=== STEP 2: Creating Silver Layer (Iceberg in MinIO) ===' AS info;

SET allow_experimental_insert_into_iceberg = 1;

-- Attach to the Iceberg table created via REST API
USE default;

CREATE TABLE IF NOT EXISTS silver_orders_iceberg
(
    order_id Int32,
    user_id Int32,
    product_id Int32,
    status LowCardinality(String),
    order_month Date,
    order_date DateTime,
    total_amount Decimal(12, 2)
) ENGINE = Iceberg(minio_iceberg, filename = 'demo_lakehouse_silver/orders_curated');

INSERT INTO silver_orders_iceberg
SELECT 
    id AS order_id,
    user_id,
    product_id,
    status,
    toDate(order_date) AS order_month,
    order_date,
    total_amount
FROM demo_lakehouse_db.`iceberg_job_demo_db.orders`;

SELECT 'Silver orders rows (Iceberg in MinIO)' AS metric, COUNT(*) AS value FROM silver_orders_iceberg;

-- ============================================================================
-- STEP 3: Create Gold Layer (Pre-aggregated KPIs in ClickHouse)
-- ============================================================================
SELECT '=== STEP 3: Creating Gold Layer ===' AS info;

DROP TABLE IF EXISTS ch_gold_order_metrics;
CREATE TABLE ch_gold_order_metrics
(
    order_month Date,
    status LowCardinality(String),
    user_count UInt64,
    order_count UInt64,
    gross_revenue Decimal(18, 2),
    avg_order_value Decimal(18, 2)
) ENGINE = MergeTree
ORDER BY (order_month, status);

INSERT INTO ch_gold_order_metrics
SELECT 
    order_month,
    status,
    uniqExact(user_id) AS user_count,
    count() AS order_count,
    sum(total_amount) AS gross_revenue,
    round(sum(total_amount) / NULLIF(count(), 0), 2) AS avg_order_value
FROM default.silver_orders_iceberg
GROUP BY order_month, status;

SELECT 'Gold metrics rows' AS metric, COUNT(*) AS value FROM ch_gold_order_metrics;

-- ============================================================================
-- SUMMARY
-- ============================================================================
SELECT '=== Setup Complete! ===' AS info;
SELECT 'You can now query:' AS '';
SELECT '  - Raw Iceberg tables: demo_lakehouse_db.`iceberg_job_demo_db.*` (MinIO)' AS tables;
SELECT '  - Silver Iceberg table: default.silver_orders_iceberg (MinIO)' AS tables;
SELECT '  - Gold metrics: default.ch_gold_order_metrics (local, pre-aggregated)' AS tables;

