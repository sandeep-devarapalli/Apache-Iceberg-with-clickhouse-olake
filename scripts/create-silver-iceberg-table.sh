#!/usr/bin/env bash

set -euo pipefail

API_URL=${ICEBERG_REST_URL:-http://localhost:8181/v1}
NAMESPACE="demo_lakehouse_silver"
TABLE_NAME="orders_curated"

echo "Ensuring Iceberg namespace '${NAMESPACE}' exists..."
curl -s -o /dev/null -w "%{http_code}\n" \
  -X POST "${API_URL}/namespaces" \
  -H "Content-Type: application/json" \
  -d "{\"namespace\": [\"${NAMESPACE}\"]}" \
  | grep -E "^(200|201|204|409)$" >/dev/null || {
    echo "Failed to create namespace ${NAMESPACE}"
    exit 1
  }

echo "Cleaning up any existing table metadata in catalog and MinIO..."
curl -s -o /tmp/delete-table-response.json -w "%{http_code}" \
  -X DELETE "${API_URL}/namespaces/${NAMESPACE}/tables/${TABLE_NAME}" \
  -H "Content-Type: application/json" \
  >/dev/null || true

# Use a temporary mc container to clean up MinIO data (mc container exits after initialization)
docker run --rm --network apache-iceberg-with-clickhouse-olake_clickhouse_lakehouse-net \
  -e MC_HOST_minio=http://admin:password@minio:9090 \
  minio/mc rm -r --force "minio/warehouse/${NAMESPACE}/${TABLE_NAME}" >/dev/null 2>&1 || true

echo "Creating (or replacing) Iceberg table '${NAMESPACE}.${TABLE_NAME}' in MinIO..."
CREATE_PAYLOAD=$(cat <<'JSON'
{
  "name": "orders_curated",
  "schema": {
    "type": "struct",
    "fields": [
      { "id": 1, "name": "order_id",     "type": "int",       "required": true  },
      { "id": 2, "name": "user_id",      "type": "int",       "required": true  },
      { "id": 3, "name": "product_id",   "type": "int",       "required": true  },
      { "id": 4, "name": "status",       "type": "string",    "required": true  },
      { "id": 5, "name": "order_month",  "type": "date",      "required": false },
      { "id": 6, "name": "order_date",   "type": "timestamp", "required": false },
      { "id": 7, "name": "total_amount", "type": "double", "required": false }
    ]
  },
  "partitionSpec": {
    "specId": 0,
    "fields": [
      { "source-id": 5, "field-id": 1000, "name": "order_month", "transform": "identity" },
      { "source-id": 4, "field-id": 1001, "name": "status",      "transform": "identity" }
    ]
  },
  "sortOrder": {
    "orderId": 0,
    "fields": []
  },
  "properties": {
    "format-version": "2",
    "write.format.default": "parquet",
    "engine.hint": "clickhouse"
  }
}
JSON
)

HTTP_CODE=$(curl -s -o /tmp/create-table-response.json -w "%{http_code}" \
  -X POST "${API_URL}/namespaces/${NAMESPACE}/tables" \
  -H "Content-Type: application/json" \
  -d "${CREATE_PAYLOAD}")

if [[ "${HTTP_CODE}" != "200" && "${HTTP_CODE}" != "201" && "${HTTP_CODE}" != "202" && "${HTTP_CODE}" != "409" ]]; then
  echo "Failed to create table ${NAMESPACE}.${TABLE_NAME} (HTTP ${HTTP_CODE})"
  cat /tmp/create-table-response.json
  exit 1
fi

echo "Table ${NAMESPACE}.${TABLE_NAME} is ready in Iceberg."
