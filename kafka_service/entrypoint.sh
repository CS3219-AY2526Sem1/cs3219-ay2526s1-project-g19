#!/bin/bash
set -e

echo "[Kafka] Starting Kafka KRaft setup (v5)..."

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

# Clean up any _schemas topic partitions (topic name gets encoded in directory)
# This ensures schema registry can create the topic with correct cleanup.policy=compact
if ls "${KAFKA_LOG_DIRS}"/*schemas* 2>/dev/null; then
    echo "[Kafka] Found existing _schemas topic data, removing to force recreation with correct policy..."
    rm -rf "${KAFKA_LOG_DIRS}"/*schemas*
fi

# Clean up broker registration metadata to avoid duplicate broker registration errors
# This happens when a new container starts before the old one properly unregistered
REGISTRATION_DIR="${KAFKA_LOG_DIRS}/__cluster_metadata-0"
if [ -d "$REGISTRATION_DIR" ]; then
    echo "[Kafka] Found existing cluster metadata directory"
    # Check if there are active log segments that indicate broker might still be registered
    # If no .log files modified in the last 2 minutes, consider it stale
    STALE_METADATA=$(find "$REGISTRATION_DIR" -name "*.log" -mmin +2 2>/dev/null | wc -l)
    if [ "$STALE_METADATA" -gt 0 ]; then
        echo "[Kafka] Detected potentially stale broker registration, cleaning up..."
        echo "[Kafka] This prevents duplicate broker registration errors during rolling deployments"
        rm -rf "$REGISTRATION_DIR"
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
