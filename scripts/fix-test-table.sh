#!/bin/bash
# Script to fix the test_olake table by either creating the metadata file or removing the catalog entry
# This helps OLake's test connection succeed

set -e

echo "Checking test_olake table status..."

# Check if the metadata file exists in MinIO
METADATA_LOCATION=$(docker exec postgres psql -U iceberg -d iceberg -t -c "SELECT metadata_location FROM iceberg_tables WHERE table_namespace = 'test_olake' AND table_name = 'test_olake';" 2>/dev/null | tr -d ' ')

if [ -n "$METADATA_LOCATION" ]; then
    echo "Found catalog entry with metadata_location: $METADATA_LOCATION"
    
    # Extract the bucket path
    S3_PATH=$(echo "$METADATA_LOCATION" | sed 's|s3://warehouse/||')
    
    # Check if file exists in MinIO
    FILE_EXISTS=$(docker run --rm --network apache-iceberg-with-clickhouse-olake_clickhouse_lakehouse-net \
      -e MC_HOST_minio=http://admin:password@minio:9090 \
      minio/mc mc stat "minio/warehouse/$S3_PATH" 2>&1 | grep -c "Object does not exist" || echo "0")
    
    if [ "$FILE_EXISTS" != "0" ]; then
        echo "Metadata file does not exist in MinIO. Removing catalog entry..."
        
        # Delete the catalog entry
        docker exec postgres psql -U iceberg -d iceberg -c "
        DELETE FROM iceberg_tables 
        WHERE table_namespace = 'test_olake' AND table_name = 'test_olake';
        " 2>&1 | grep -v "DELETE\|^$"
        
        # Also delete namespace if empty
        docker exec postgres psql -U iceberg -d iceberg -c "
        DELETE FROM iceberg_namespace_properties 
        WHERE namespace = ARRAY['test_olake'];
        " 2>&1 | grep -v "DELETE\|^$"
        
        echo "✅ Catalog entry removed. Test connection should now work (though it may still fail if it tries to read a non-existent table)."
        echo "   The proper solution is to proceed with creating the pipeline - it will create tables correctly."
    else
        echo "✅ Metadata file exists. Test connection should work."
    fi
else
    echo "No test_olake table found in catalog. This is expected for a fresh setup."
    echo "Test connection may fail until tables are created by a pipeline run."
fi

echo ""
echo "Note: If test connection still fails, proceed to create the pipeline anyway."
echo "The pipeline execution will succeed even if the test fails."

