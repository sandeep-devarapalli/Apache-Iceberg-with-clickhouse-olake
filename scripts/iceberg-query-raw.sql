-- Step 1: Query Raw Iceberg Tables
-- This script connects to the REST catalog and queries the raw Iceberg tables written by OLake
-- Run this first to verify the connection and see the data

-- Enable experimental Iceberg database feature
SET allow_experimental_database_iceberg = 1;
SET use_iceberg_partition_pruning = 1;
SET use_iceberg_metadata_files_cache = 1;

-- Create database connection to REST catalog using DataLakeCatalog engine
-- Note: Update the warehouse name to match your OLake pipeline namespace
-- Format: <job_name>_<database_name> (e.g., 'iceberg_job_demo_db' if job is 'iceberg_job' and database is 'demo_db')
DROP DATABASE IF EXISTS demo_lakehouse_db;
CREATE DATABASE demo_lakehouse_db
ENGINE = DataLakeCatalog('http://iceberg-rest:8181/v1', 'admin', 'password')
SETTINGS 
    catalog_type = 'rest', 
    storage_endpoint = 'http://minio:9090/warehouse', 
    warehouse = 'iceberg_job_demo_db';

-- Now we can query tables through the database
-- Note: Use backticks for table names with namespaces
USE demo_lakehouse_db;

-- Show available tables
SELECT '=== Available tables in REST catalog ===' AS info;
SHOW TABLES;

-- Query the raw Iceberg tables (written by OLake)
-- Note: The namespace matches the warehouse setting above
-- Note: First queries may be slow (2-5 seconds) due to:
--   - Fetching metadata from REST catalog
--   - Reading Parquet files from MinIO over network
--   - No local caching on first access
SELECT '=== Raw Iceberg Table Row Counts ===' AS info;
SELECT 'Iceberg users rows' AS metric, COUNT(*) AS value FROM `iceberg_job_demo_db.users`;
SELECT 'Iceberg products rows' AS metric, COUNT(*) AS value FROM `iceberg_job_demo_db.products`;
SELECT 'Iceberg orders rows' AS metric, COUNT(*) AS value FROM `iceberg_job_demo_db.orders`;
SELECT 'Iceberg user_sessions rows' AS metric, COUNT(*) AS value FROM `iceberg_job_demo_db.user_sessions`;

-- Sample queries to verify data
SELECT '=== Sample Data Verification ===' AS info;
SELECT 'Sample users (first 5):' AS info;
SELECT id, username, email, country FROM `iceberg_job_demo_db.users` LIMIT 5;

SELECT 'Sample orders by status:' AS info;
SELECT status, COUNT(*) AS count FROM `iceberg_job_demo_db.orders` GROUP BY status;

SELECT '=== Step 1 Complete: Raw tables are accessible ===' AS info;
SELECT 'You can now proceed to Step 2: Create Silver Layer' AS next_step;

