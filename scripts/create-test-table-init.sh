#!/bin/sh
# Script to create test table for OLake connection testing
# This is called by the init-test-table service in docker-compose

echo 'Waiting for REST catalog to be fully ready...';
sleep 10;

until curl -sf http://iceberg-rest:8181/v1/config > /dev/null; do
  echo 'Waiting for REST catalog...';
  sleep 2;
done;

echo 'Creating test_olake namespace...';
curl -s -X PUT http://iceberg-rest:8181/v1/namespaces/test_olake \
  -H 'Content-Type: application/json' \
  -d '{}' > /dev/null 2>&1 || echo 'Namespace may already exist';

echo 'Creating test_olake table for OLake connection testing...';

# Create the table JSON payload
# Schema matches what OLake expects for test connection:
# - id: optional long (OLake may send null)
# - name: optional string (OLake sends {"name":"olake"})
TABLE_JSON='{"name":"test_olake","schema":{"type":"struct","schema-id":0,"fields":[{"id":1,"name":"id","type":"long","required":false},{"id":2,"name":"name","type":"string","required":false}]},"partition-spec":{"spec-id":0,"fields":[]},"write-order-spec":{"order-id":0,"fields":[]},"stage-create":false,"properties":{"write.format.default":"parquet"}}';

RESPONSE=$(curl -s -w '\n%{http_code}' -X POST http://iceberg-rest:8181/v1/namespaces/test_olake/tables \
  -H 'Content-Type: application/json' \
  -d "$TABLE_JSON");

HTTP_CODE=$(echo "$RESPONSE" | tail -n1);
BODY=$(echo "$RESPONSE" | sed '$d');

if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "201" ]; then
  echo '✅ Test table created successfully! OLake test connection should now work.';
  exit 0;
else
  echo "⚠️  Test table creation returned HTTP $HTTP_CODE";
  echo "Response: $BODY" | head -c 500;
  echo "";
  echo "This is okay - you can still proceed with creating the pipeline.";
  exit 0;
fi;

