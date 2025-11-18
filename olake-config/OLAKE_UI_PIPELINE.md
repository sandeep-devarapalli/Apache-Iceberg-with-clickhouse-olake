## OLake UI Pipeline Blueprint

Use this runbook as you configure the OLake UI (http://localhost:8000 by default) to replicate MySQL tables into MinIO-backed Apache Iceberg tables.

### 1. Log in
- URL: `http://localhost:8000`
- Default credentials: `admin` / `password`

### 2. Register the Source (MySQL)
1. Navigate to **Sources → New Source → MySQL**.
2. Fill in the values:
   - Host: `mysql`
   - Port: `3306`
   - Database: `demo_db`
   - Username: `olake`
   - Password: `olake_pass`
   - Enable SSL: `false`
3. Select the tables: `users`, `products`, `orders`, `user_sessions`.
4. Advanced options:
   - Chunk Size: `1000`
   - CDC: enabled (uses existing binlog config).

### 3. Register the Destination (Iceberg on MinIO)
1. Go to **Destinations → New Destination → Iceberg (S3/Hadoop catalog)**.
2. Catalog section:
   - Type: `hadoop`
   - Warehouse: `s3a://iceberg-warehouse/`
   - Metastore URI: leave blank (MinIO does not need HMS for demo).
3. Storage section:
   - Endpoint: `http://minio:9000`
   - Access Key: `minioadmin`
   - Secret Key: `minioadmin123`
   - Region: `us-east-1`
   - Bucket: `iceberg-warehouse`
   - Path Style Access: enabled
   - SSL: disabled
4. Format: `Parquet`, compression `snappy`.
5. Partition defaults: enable and keep per-table overrides below.

### 4. Build the Pipeline
Create a pipeline per table or a single multi-table pipeline.

| Source Table | Namespace | Destination Table | Partition Strategy                      | Primary Key |
|--------------|-----------|-------------------|-----------------------------------------|-------------|
| `users`      | `demo_lakehouse` | `users`      | `month(created_at)`, `identity(country)` | `id` |
| `products`   | `demo_lakehouse` | `products`   | `identity(category)`                    | `id` |
| `orders`     | `demo_lakehouse` | `orders`     | `month(order_date)`, `identity(status)` | `id` |
| `user_sessions` | `demo_lakehouse` | `user_sessions` | `day(login_time)`                   | `id` |

Recommended write options:
- Mode: `upsert`
- Merge Strategy: `merge_on_read`
- Batch size: `10000`
- Flush interval: `60s`
- Commit interval: `300s`

### 5. Start and Monitor
1. Start the pipeline and watch the first full load finish.
2. Verify row counts from the monitoring tab; each Iceberg table path is `s3a://iceberg-warehouse/demo_lakehouse/<table>`.

### 6. Query with ClickHouse
Run `clickhouse-client --host clickhouse` and execute `scripts/iceberg-setup.sql` to materialize the `IcebergS3` tables that point to the MinIO objects synchronized by OLake UI.


