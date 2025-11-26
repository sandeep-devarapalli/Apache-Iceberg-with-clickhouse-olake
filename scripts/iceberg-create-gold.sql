-- Step 3: Create Gold Layer (Pre-aggregated KPIs in ClickHouse Local Storage)
-- This script creates pre-aggregated metrics in ClickHouse local storage for fastest queries
-- The gold layer is stored locally in ClickHouse as MergeTree tables

SELECT '=== Creating Gold Layer (Pre-aggregated KPIs) ===' AS info;

USE default;

-- Create ClickHouse-managed "gold" layer for aggregated KPIs (local storage)
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

SELECT '=== Aggregating data from Silver layer (Iceberg in MinIO) ===' AS info;

-- Insert aggregated data from silver layer into gold table
-- Note: We can query from either the attached silver_orders_iceberg view or the REST catalog
-- Query from the silver Iceberg table
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

SELECT '=== Gold Layer Created Successfully ===' AS info;
SELECT 'Gold metrics rows' AS metric, COUNT(*) AS value FROM ch_gold_order_metrics;

-- Show sample gold metrics
SELECT '=== Sample Gold Metrics ===' AS info;
SELECT 
    order_month,
    status,
    user_count,
    order_count,
    gross_revenue,
    avg_order_value
FROM ch_gold_order_metrics
ORDER BY order_month DESC, status
LIMIT 10;

-- Summary of all layers
SELECT '=== All Layers Summary ===' AS info;
SELECT 'Raw Iceberg (MinIO): demo_lakehouse_db.`iceberg_job_demo_db.*`' AS layer;
SELECT 'Silver Iceberg (MinIO): default.silver_orders_iceberg' AS layer;
SELECT 'Gold Metrics (Local): default.ch_gold_order_metrics' AS layer;

SELECT '=== Step 3 Complete: Gold layer created ===' AS info;
SELECT 'All three layers are now ready for querying!' AS completion;

