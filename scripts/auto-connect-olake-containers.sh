#!/bin/bash
# Script to automatically connect OLake dynamically created containers to the network
# Uses Docker events API for immediate connection when containers are created

NETWORK_NAME="apache-iceberg-with-clickhouse-olake_clickhouse_lakehouse-net"

echo "Watching for OLake test containers and connecting them to network $NETWORK_NAME..."
echo "Press Ctrl+C to stop"

# Function to connect a container to the network
connect_container() {
  local container=$1
  # Check if container matches our patterns and isn't already on the network
  if echo "$container" | grep -qiE "(test|destination|iceberg|fetch-spec)" && \
     ! echo "$container" | grep -qiE "(olake-ui|olake-temporal-worker|olake-signup-init|iceberg-rest)"; then
    if ! docker inspect "$container" --format '{{range $net, $conf := .NetworkSettings.Networks}}{{$net}} {{end}}' 2>/dev/null | grep -q "$NETWORK_NAME"; then
      echo "[$(date +'%Y-%m-%d %H:%M:%S')] Connecting $container to $NETWORK_NAME..."
      if docker network connect "$NETWORK_NAME" "$container" 2>/dev/null; then
        echo "  ✓ Connected $container"
        return 0
      else
        echo "  ✗ Failed to connect $container (may have exited)"
        return 1
      fi
    fi
  fi
  return 0
}

# Connect any existing containers first
echo "Connecting existing containers..."
for container in $(docker ps -a --format "{{.Names}}" 2>/dev/null); do
  connect_container "$container"
done

# Watch for new container events - connect on both create and start
echo "Watching for new containers..."
# Use a background process to watch events and a polling loop as backup
(
  docker events --filter 'type=container' --format '{{.Actor.Attributes.name}} {{.Status}}' 2>/dev/null | while read -r container event; do
    if echo "$event" | grep -qE "(create|start)"; then
      connect_container "$container"
    fi
  done
) &

# Also run a fast polling loop as backup (every 100ms)
while true; do
  for container in $(docker ps -a --format "{{.Names}}" 2>/dev/null); do
    connect_container "$container" >/dev/null 2>&1
  done
  sleep 0.1
done

