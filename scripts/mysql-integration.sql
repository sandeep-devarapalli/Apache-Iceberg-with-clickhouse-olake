-- Smoke test: query the Iceberg REST catalog directly (no MySQL engine tables)
SET allow_experimental_insert_into_iceberg = 1;

WITH
    'http://olake-ui:8181/api/catalog' AS catalog_endpoint,
    'demo_lakehouse' AS catalog_namespace,
    'admin' AS catalog_user,
    'password' AS catalog_password
SELECT 'Iceberg REST Orders Rows' AS test,
       COUNT(*) AS row_count
FROM iceberg(
    'rest',
    catalog_endpoint,
    catalog_namespace,
    'orders',
    catalog_user,
    catalog_password
);
