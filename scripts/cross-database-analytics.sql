SELECT 'ICEBERG ANALYTICS DEMONSTRATION' as title;

-- Raw tables served via the Iceberg REST catalog
SELECT 'Raw Iceberg Orders (REST Catalog)' as source;
SELECT 
    status,
    COUNT(*) as order_count,
    ROUND(AVG(total_amount), 2) as avg_order_value,
    MIN(order_date) as first_order,
    MAX(order_date) as most_recent_order
FROM iceberg_orders_lakehouse
GROUP BY status
ORDER BY order_count DESC;

-- Raw vs optimized ClickHouse layers
SELECT 'RAW ICEBERG (REST)' AS layer,
       status,
       COUNT(*) AS order_count,
       ROUND(AVG(total_amount), 2) AS avg_order_value
FROM iceberg_orders_lakehouse
GROUP BY status
ORDER BY order_count DESC;

SELECT 'SILVER (Optimized Iceberg in MinIO)' AS layer,
       status,
       COUNT(*) AS order_count,
       ROUND(AVG(total_amount), 2) AS avg_order_value
FROM iceberg_silver_orders
GROUP BY status
ORDER BY order_count DESC;

SELECT 'GOLD (Aggregated KPIs)' AS layer,
       status,
       SUM(order_count) AS aggregated_orders,
       ROUND(AVG(avg_order_value), 2) AS avg_order_value
FROM ch_gold_order_metrics
GROUP BY status
ORDER BY aggregated_orders DESC;
