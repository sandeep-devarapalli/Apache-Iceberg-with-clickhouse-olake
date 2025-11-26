#!/bin/bash
# Performance comparison script with actual timing
# This script runs the same queries against raw, silver, and gold tables and shows execution times

echo "=== QUERY PERFORMANCE COMPARISON WITH TIMING ==="
echo ""
echo "Setting up database connection for raw Iceberg tables..."
echo ""

# Set up database connection for raw Iceberg tables
docker exec -i clickhouse-server clickhouse-client --query "
SET allow_database_iceberg = 1;
SET allow_experimental_database_iceberg = 1;
DROP DATABASE IF EXISTS demo_lakehouse_db;
CREATE DATABASE demo_lakehouse_db
ENGINE = DataLakeCatalog('http://iceberg-rest:8181/v1', 'admin', 'password')
SETTINGS 
    catalog_type = 'rest', 
    storage_endpoint = 'http://minio:9090/warehouse', 
    warehouse = 'iceberg_job_demo_db';
" > /dev/null 2>&1

echo "Running the same query against all three layers..."
echo ""

QUERY="SELECT status, COUNT(*) AS orders, ROUND(AVG(total_amount), 2) AS avg_value FROM"

echo "--- RAW ICEBERG (REST Catalog) ---"
echo "Query: USE demo_lakehouse_db; $QUERY \`iceberg_job_demo_db.orders\` GROUP BY status"
echo ""
time docker exec -i clickhouse-server clickhouse-client --query "USE demo_lakehouse_db; $QUERY \`iceberg_job_demo_db.orders\` GROUP BY status ORDER BY orders DESC" --format=Pretty 2>&1 | head -20
echo ""

echo "--- SILVER (Optimized Iceberg in MinIO) ---"
echo "Query: USE default; $QUERY silver_orders_iceberg GROUP BY status"
echo ""
time docker exec -i clickhouse-server clickhouse-client --query "USE default; $QUERY silver_orders_iceberg GROUP BY status ORDER BY orders DESC" --format=Pretty 2>&1 | head -20
echo ""

echo "--- GOLD (Pre-aggregated KPIs) ---"
echo "Query: SELECT status, SUM(order_count) AS orders, ROUND(AVG(avg_order_value), 2) AS avg_value FROM ch_gold_order_metrics GROUP BY status"
echo ""
time docker exec -i clickhouse-server clickhouse-client --query "SELECT status, SUM(order_count) AS orders, ROUND(AVG(avg_order_value), 2) AS avg_value FROM ch_gold_order_metrics GROUP BY status ORDER BY orders DESC" --format=Pretty 2>&1 | head -20
echo ""

echo "=== SUMMARY ==="
echo "The 'time' command shows:"
echo "  - real: Wall clock time (what you experience)"
echo "  - user: CPU time spent in user mode"
echo "  - sys: CPU time spent in system mode"
echo ""
echo "Expected differences with 10,000+ orders:"
echo "  - Raw Iceberg: 2-5 seconds (network I/O, Parquet parsing, unoptimized layout)"
echo "  - Silver Iceberg: 500ms-2 seconds (ClickHouse-optimized Iceberg in MinIO, better partitioning)"
echo "  - Gold: 10-50 milliseconds (pre-aggregated metrics in ClickHouse local storage)"

