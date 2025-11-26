#!/bin/bash
# Script to set up Iceberg database in PostgreSQL for REST Catalog

echo "Setting up Iceberg database in PostgreSQL..."

docker exec -i iceberg-postgresql psql -U postgres -d postgres <<EOF
-- Create the iceberg user if it doesn't exist
DO \$\$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_user WHERE usename = 'iceberg') THEN
    CREATE USER iceberg WITH PASSWORD 'iceberg_pass';
    RAISE NOTICE 'User iceberg created';
  ELSE
    RAISE NOTICE 'User iceberg already exists';
  END IF;
END
\$\$;

-- Create the iceberg database if it doesn't exist
SELECT 'CREATE DATABASE iceberg'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'iceberg')\gexec

-- Grant privileges
GRANT ALL PRIVILEGES ON DATABASE iceberg TO iceberg;

-- Connect to iceberg database and grant schema privileges
\c iceberg

GRANT ALL ON SCHEMA public TO iceberg;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO iceberg;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO iceberg;

\q
EOF

echo "Iceberg database setup complete!"

