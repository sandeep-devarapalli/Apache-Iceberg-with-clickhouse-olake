SET allow_experimental_insert_into_iceberg = 1;
SET use_iceberg_partition_pruning = 1;
SET use_iceberg_metadata_files_cache = 1;

DROP TABLE IF EXISTS iceberg_users_lakehouse;
WITH
    'http://olake-ui:8181/api/catalog' AS catalog_endpoint,
    'demo_lakehouse' AS catalog_namespace,
    'admin' AS catalog_user,
    'password' AS catalog_password
CREATE TABLE iceberg_users_lakehouse
ENGINE = Iceberg('rest', catalog_endpoint, catalog_namespace, 'users', catalog_user, catalog_password);
SELECT 'Iceberg users rows' AS metric, COUNT(*) AS value FROM iceberg_users_lakehouse;

DROP TABLE IF EXISTS iceberg_products_lakehouse;
WITH
    'http://olake-ui:8181/api/catalog' AS catalog_endpoint,
    'demo_lakehouse' AS catalog_namespace,
    'admin' AS catalog_user,
    'password' AS catalog_password
CREATE TABLE iceberg_products_lakehouse
ENGINE = Iceberg('rest', catalog_endpoint, catalog_namespace, 'products', catalog_user, catalog_password);
SELECT 'Iceberg products rows' AS metric, COUNT(*) AS value FROM iceberg_products_lakehouse;

DROP TABLE IF EXISTS iceberg_orders_lakehouse;
WITH
    'http://olake-ui:8181/api/catalog' AS catalog_endpoint,
    'demo_lakehouse' AS catalog_namespace,
    'admin' AS catalog_user,
    'password' AS catalog_password
CREATE TABLE iceberg_orders_lakehouse
ENGINE = Iceberg('rest', catalog_endpoint, catalog_namespace, 'orders', catalog_user, catalog_password);
SELECT 'Iceberg orders rows' AS metric, COUNT(*) AS value FROM iceberg_orders_lakehouse;

DROP TABLE IF EXISTS iceberg_user_sessions_lakehouse;
WITH
    'http://olake-ui:8181/api/catalog' AS catalog_endpoint,
    'demo_lakehouse' AS catalog_namespace,
    'admin' AS catalog_user,
    'password' AS catalog_password
CREATE TABLE iceberg_user_sessions_lakehouse
ENGINE = Iceberg('rest', catalog_endpoint, catalog_namespace, 'user_sessions', catalog_user, catalog_password);
SELECT 'Iceberg user_sessions rows' AS metric, COUNT(*) AS value FROM iceberg_user_sessions_lakehouse;

-- Create ClickHouse-managed "silver" layer for frequently queried columns
DROP TABLE IF EXISTS ch_silver_orders;
CREATE TABLE ch_silver_orders
(
    order_id Int32,
    user_id Int32,
    product_id Int32,
    status LowCardinality(String),
    order_month Date,
    order_date DateTime,
    total_amount Decimal(12, 2)
) ENGINE = MergeTree
ORDER BY (order_month, status, user_id, order_id);

INSERT INTO ch_silver_orders
SELECT 
    id,
    user_id,
    product_id,
    status,
    toDate(order_date),
    order_date,
    total_amount
FROM iceberg_orders_lakehouse;

SELECT 'Silver orders rows' AS metric, COUNT(*) AS value FROM ch_silver_orders;

-- Create ClickHouse-managed "gold" layer for aggregated KPIs
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
FROM ch_silver_orders
GROUP BY order_month, status;

SELECT 'Gold metrics rows' AS metric, COUNT(*) AS value FROM ch_gold_order_metrics;
