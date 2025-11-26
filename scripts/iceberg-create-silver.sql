-- Step 2: Create Silver Layer (Optimized Iceberg Tables in MinIO)
-- This script reads raw Iceberg tables from MinIO and writes a curated Iceberg table back to MinIO
-- Prerequisites:
--   1. Run scripts/create-silver-iceberg-table.sh to create the target Iceberg table via the REST catalog
--   2. Ensure clickhouse-config/minio-iceberg.xml is loaded (docker-compose restart clickhouse)

SET allow_experimental_database_iceberg = 1;
SET allow_experimental_insert_into_iceberg = 1;
SET use_iceberg_partition_pruning = 1;
SET use_iceberg_metadata_files_cache = 1;

SELECT '=== Creating Silver Layer in MinIO (Iceberg) ===' AS info;

-- Ensure raw database connection exists
DROP DATABASE IF EXISTS demo_lakehouse_db;
CREATE DATABASE demo_lakehouse_db
ENGINE = DataLakeCatalog('http://iceberg-rest:8181/v1', 'admin', 'password')
SETTINGS 
    catalog_type = 'rest', 
    storage_endpoint = 'http://minio:9090/warehouse', 
    warehouse = 'iceberg_job_demo_db';

-- Create a database connection to the silver namespace for verification
DROP DATABASE IF EXISTS demo_lakehouse_silver_db;
CREATE DATABASE demo_lakehouse_silver_db
ENGINE = DataLakeCatalog('http://iceberg-rest:8181/v1', 'admin', 'password')
SETTINGS 
    catalog_type = 'rest', 
    storage_endpoint = 'http://minio:9090/warehouse', 
    warehouse = 'demo_lakehouse_silver';

USE default;

-- Attach to the Iceberg table that was created via REST API / Spark
CREATE TABLE IF NOT EXISTS silver_orders_iceberg
(
    order_id Int32,
    user_id Int32,
    product_id Int32,
    status String,
    order_month Date,
    order_date DateTime,
    total_amount Float64
) ENGINE = Iceberg(minio_iceberg, filename = 'demo_lakehouse_silver/orders_curated');

SELECT '=== Inserting optimized data into silver Iceberg table ===' AS info;
SELECT 'This reads raw Iceberg (MinIO) and writes a curated Iceberg table (MinIO)...' AS info;

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

SELECT '=== Silver Layer Created Successfully (Iceberg in MinIO) ===' AS info;
SELECT 'Silver orders rows (Iceberg)' AS metric, COUNT(*) AS value FROM silver_orders_iceberg;

-- Verify the table and show sample queries
SELECT '=== Querying Silver Table ===' AS info;
SELECT status, COUNT(*) AS orders, ROUND(AVG(total_amount), 2) AS avg_value
FROM silver_orders_iceberg
GROUP BY status;

SELECT '=== Location Note ===' AS info;
SELECT 'Silver layer is an Iceberg table stored in MinIO (demo_lakehouse_silver/orders_curated).' AS note;

SELECT '=== Step 2 Complete: Silver layer created in MinIO ===' AS info;
SELECT 'You can now proceed to Step 3: Create Gold Layer' AS next_step;

