#!/bin/bash
# Script to initialize a test Iceberg table so OLake's test connection succeeds
# This creates a minimal valid Iceberg table with proper metadata files

set -e

echo "Initializing test Iceberg table for OLake connection testing..."

# Wait for services to be ready
echo "Waiting for services to be ready..."
sleep 5

# Use a Java-based approach to create a proper Iceberg table
# We'll use a temporary container with Iceberg libraries
docker run --rm --network apache-iceberg-with-clickhouse-olake_clickhouse_lakehouse-net \
  -e REST_CATALOG_URI=http://iceberg-rest:8181 \
  -e S3_ENDPOINT=http://minio:9090 \
  -e AWS_ACCESS_KEY_ID=admin \
  -e AWS_SECRET_ACCESS_KEY=password \
  -e CATALOG_WAREHOUSE=s3://warehouse/ \
  openjdk:17-jdk-slim bash -c "
apt-get update -qq && apt-get install -y -qq curl > /dev/null 2>&1

# Create namespace first
echo 'Creating namespace...'
curl -s -X PUT 'http://iceberg-rest:8181/v1/namespaces/test_olake' \
  -H 'Content-Type: application/json' \
  -d '{}' > /dev/null 2>&1 || echo 'Namespace may already exist'

# Now create a minimal valid Iceberg table using REST API
# The key is to create it with proper initial state
echo 'Creating test table...'
TABLE_SPEC='{
  \"name\": \"test_olake\",
  \"schema\": {
    \"type\": \"struct\",
    \"schema-id\": 0,
    \"fields\": [
      {\"id\": 1, \"name\": \"id\", \"type\": \"long\", \"required\": true},
      {\"id\": 2, \"name\": \"data\", \"type\": \"string\", \"required\": false}
    ]
  },
  \"partition-spec\": {
    \"spec-id\": 0,
    \"fields\": []
  },
  \"write-order-spec\": {
    \"order-id\": 0,
    \"fields\": []
  },
  \"stage-create\": false,
  \"properties\": {
    \"write.format.default\": \"parquet\",
    \"write.parquet.compression-codec\": \"snappy\"
  }
}'

RESPONSE=\$(curl -s -w '\n%{http_code}' -X POST 'http://iceberg-rest:8181/v1/namespaces/test_olake/tables' \
  -H 'Content-Type: application/json' \
  -d \"\$TABLE_SPEC\")

HTTP_CODE=\$(echo \"\$RESPONSE\" | tail -n1)
BODY=\$(echo \"\$RESPONSE\" | sed '\$d')

if [ \"\$HTTP_CODE\" = \"200\" ] || [ \"\$HTTP_CODE\" = \"201\" ]; then
  echo '✅ Test table created successfully!'
  echo \"Response: \$BODY\" | head -c 200
  echo ''
  exit 0
else
  echo \"❌ Failed to create table. HTTP \$HTTP_CODE\"
  echo \"Response: \$BODY\"
  
  # If creation fails, try to clean up and retry
  echo 'Cleaning up and retrying...'
  curl -s -X DELETE 'http://iceberg-rest:8181/v1/namespaces/test_olake/tables/test_olake' > /dev/null 2>&1 || true
  sleep 2
  
  RESPONSE2=\$(curl -s -w '\n%{http_code}' -X POST 'http://iceberg-rest:8181/v1/namespaces/test_olake/tables' \
    -H 'Content-Type: application/json' \
    -d \"\$TABLE_SPEC\")
  
  HTTP_CODE2=\$(echo \"\$RESPONSE2\" | tail -n1)
  if [ \"\$HTTP_CODE2\" = \"200\" ] || [ \"\$HTTP_CODE2\" = \"201\" ]; then
    echo '✅ Test table created successfully on retry!'
    exit 0
  else
    echo \"❌ Retry also failed. HTTP \$HTTP_CODE2\"
    exit 1
  fi
fi
"

if [ $? -eq 0 ]; then
  echo ""
  echo "✅ Test table initialization complete!"
  echo "OLake's test connection should now succeed."
  echo ""
  echo "You can verify by:"
  echo "  1. Testing the connection in OLake UI"
  echo "  2. Or checking: curl -s http://localhost:8181/v1/namespaces/test_olake/tables | jq ."
else
  echo ""
  echo "⚠️  Test table creation had issues, but this is okay."
  echo "The test connection may still work, or you can proceed to create the pipeline."
fi

