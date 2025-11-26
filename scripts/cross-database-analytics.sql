SELECT 'ICEBERG ANALYTICS DEMONSTRATION' as title;

-- Ensure database connection exists
SET allow_database_iceberg = 1;
SET allow_experimental_database_iceberg = 1;
DROP DATABASE IF EXISTS demo_lakehouse_db;
CREATE DATABASE demo_lakehouse_db
ENGINE = DataLakeCatalog('http://iceberg-rest:8181/v1', 'admin', 'password')
SETTINGS 
    catalog_type = 'rest', 
    storage_endpoint = 'http://minio:9090/warehouse', 
    warehouse = 'iceberg_job_demo_db';

-- Raw tables served via the Iceberg REST catalog
SELECT 'Raw Iceberg Orders (REST Catalog)' as source;
USE demo_lakehouse_db;
SELECT 
    status,
    COUNT(*) as order_count,
    ROUND(AVG(total_amount), 2) as avg_order_value,
    MIN(order_date) as first_order,
    MAX(order_date) as most_recent_order
FROM `iceberg_job_demo_db.orders`
GROUP BY status
ORDER BY order_count DESC;

-- Raw vs optimized ClickHouse layers
SELECT 'RAW ICEBERG (REST)' AS layer,
       status,
       COUNT(*) AS order_count,
       ROUND(AVG(total_amount), 2) AS avg_order_value
FROM `iceberg_job_demo_db.orders`
GROUP BY status
ORDER BY order_count DESC;

-- Switch to default database for silver and gold tables
USE default;

SELECT 'SILVER (Optimized Iceberg in MinIO)' AS layer,
       status,
       COUNT(*) AS order_count,
       ROUND(AVG(total_amount), 2) AS avg_order_value
FROM silver_orders_iceberg
GROUP BY status
ORDER BY order_count DESC;

SELECT 'GOLD (Aggregated KPIs)' AS layer,
       status,
       SUM(order_count) AS aggregated_orders,
       ROUND(AVG(avg_order_value), 2) AS avg_order_value
FROM ch_gold_order_metrics
GROUP BY status
ORDER BY aggregated_orders DESC;
