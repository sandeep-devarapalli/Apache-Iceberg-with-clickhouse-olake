# Building a Data Lakehouse with Apache Iceberg, ClickHouse & OLake UI

A comprehensive Docker-based development environment that ingests data from MySQL into MinIO-backed Apache Iceberg tables via the **OLake** and queries the lakehouse with ClickHouse. The repo walks through the full pipeline—MySQL CDC ➜ OLake ➜ Iceberg on MinIO ➜ ClickHouse analytics.

## 🏗️ Architecture Overview

```mermaid
graph TD
    A[MySQL Database] -->|CDC via OLake UI| B[OLake Pipelines]
    B -->|Iceberg Writers| D[Apache Iceberg on MinIO]
    C[ClickHouse] -->|Iceberg REST Catalog| D
    D -->|Snapshots| C
    E[Analytics Queries] --> C
    F[Time Travel Queries] --> D
    G[Schema Evolution] --> D
    
    subgraph "Data Sources"
        A
    end
    
    subgraph "Processing Layer"
        B
        C
    end
    
    subgraph "Storage Layer"
        D
    end
    
    subgraph "Analytics Layer"
        E
        F
        G
    end
```

## 🎯 What This Demo Showcases

### Core Features
- **ClickHouse Experimental Iceberg Support** - Query Iceberg tables through the REST catalog interface
- **Real-time CDC Pipeline** - MySQL → OLake → Iceberg with change data capture
- **Silver/Gold Acceleration** - Materialize ClickHouse-optimized tables on top of raw Iceberg data
- **Schema Evolution** - Add columns and modify schemas without data loss
- **Time Travel Queries** - Query historical data states
- **Partition Pruning** - Optimized query performance with intelligent partitioning

### Integration Components
- **MySQL 8.0** - Source database with sample e-commerce data
- **ClickHouse 24.11** - Analytics database with experimental Iceberg support
- **MinIO** - S3-compatible object storage for Iceberg tables
- **OLake UI** - Data lake orchestration and CDC platform (includes its own PostgreSQL, Temporal, Elasticsearch)

## 🚀 Quick Start

```bash
git clone https://github.com/sandeep-devarapalli/Apache-Iceberg-with-clickhouse-olake.git
cd Apache-Iceberg-with-clickhouse-olake
docker-compose up -d
```

- Services: MySQL, MinIO, ClickHouse, helper clients
- OLake UI runs as a separate stack (includes its own PostgreSQL, Temporal, Elasticsearch)
- Detailed instructions live in `BLOG_POST_COMPLETE_WALKTHROUGH.md`

## 🧭 Next Steps

1. **Launch OLake UI** using the [official quickstart](https://olake.io/docs/getting-started/quickstart/):
   ```bash
   # Start OLake UI (complete stack with PostgreSQL, Temporal, Elasticsearch)
   curl -sSL https://raw.githubusercontent.com/datazip-inc/olake-ui/master/docker-compose.yml | docker compose -f - up -d
   
   # Connect OLake UI container to our network (so it can reach MySQL, MinIO)
   OLAKE_CONTAINER=$(docker ps --filter "name=olake-ui" --format "{{.Names}}" | head -1)
   docker network connect clickhouse_lakehouse-net $OLAKE_CONTAINER 2>/dev/null || \
   docker network connect apache-iceberg-with-clickhouse-olake_clickhouse_lakehouse-net $OLAKE_CONTAINER
   ```
   Access at `http://localhost:8000` (default: `admin` / `password`)
   
   **Important:** In OLake UI, use Docker hostnames: `mysql:3306` and `minio:9000` (not localhost)

2. Follow the blog to configure source/destination, run the pipeline, and query via ClickHouse
3. Re-run `scripts/iceberg-setup.sql` + `scripts/cross-database-analytics.sql` whenever you load new data

For troubleshooting, scripts, and the full hands-on guide, jump into `BLOG_POST_COMPLETE_WALKTHROUGH.md`.
