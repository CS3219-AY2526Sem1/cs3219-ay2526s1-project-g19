#!/bin/bash
set -e

BOOTSTRAP="peerprep_kafka:29092"
PARTITIONS=3
REPLICATION=1

echo "Waiting for Kafka broker at $BOOTSTRAP..."

# Wait for Kafka to respond
until kafka-topics --bootstrap-server "$BOOTSTRAP" --list >/dev/null 2>&1; do
    echo "Kafka not ready yet, sleeping 2s..."
    sleep 2
done

echo "Kafka broker is ready. Creating topics..."

# Loop through all environment variables that start with TOPIC_
for VAR in $(env | grep '^TOPIC_' | cut -d= -f1); do
    TOPIC_NAME="${!VAR}"
    if [ -n "$TOPIC_NAME" ]; then
        echo "Creating topic: $TOPIC_NAME"
        kafka-topics \
            --bootstrap-server "$BOOTSTRAP" \
            --create \
            --if-not-exists \
            --topic "$TOPIC_NAME" \
            --partitions "$PARTITIONS" \
            --replication-factor "$REPLICATION"
    fi
done

echo "All topics created successfully!"
