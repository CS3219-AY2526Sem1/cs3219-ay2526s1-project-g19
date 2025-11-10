#!/bin/bash
set -e

echo "[Kafka] Starting Kafka KRaft setup (v3)..."

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
