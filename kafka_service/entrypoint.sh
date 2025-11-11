#!/bin/bash
set -e

echo "[Kafka] Starting Kafka KRaft setup (v4)..."

# Clean up stale lock file if it exists
LOCK_FILE="${KAFKA_LOG_DIRS}/.lock"
if [ -f "$LOCK_FILE" ]; then
    echo "[Kafka] Found existing lock file at $LOCK_FILE"
    # Check if any process is holding the lock
    if ! fuser "$LOCK_FILE" 2>/dev/null; then
        echo "[Kafka] Removing stale lock file (no process holding it)"
        rm -f "$LOCK_FILE"
    else
        echo "[Kafka] Lock file is in use by another process - this might indicate a problem"
    fi
fi

# Format storage if not already formatted
if [ ! -f "${KAFKA_LOG_DIRS}/meta.properties" ]; then
    echo "[Kafka] Formatting storage with cluster ID: ${CLUSTER_ID}"
    /usr/bin/kafka-storage format \
        --config /etc/kafka/kafka.properties \
        --cluster-id="${CLUSTER_ID}" \
        --ignore-formatted
fi

echo "[Kafka] Storage ready, starting Kafka broker..."

# Start Kafka using the official entrypoint
exec /etc/confluent/docker/run
