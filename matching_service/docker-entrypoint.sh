#!/bin/bash
set -e

echo "Starting matching service container..."

# # Wait for Kafka/Schema Registry to be reachable (optional but recommended)
# if [ -n "$SCHEMA_REGISTRY_URL" ]; then
#   echo "Waiting for Schema Registry at $SCHEMA_REGISTRY_URL ..."
#   until curl -sf "$SCHEMA_REGISTRY_URL/subjects" > /dev/null; do
#     sleep 2
#   done
#   echo "Schema Registry is up."
# fi

# Register schemas
if [ -f "kafka/scripts/register_schemas.py" ]; then
  echo "Registering Kafka schemas..."
  python -m kafka.scripts.register_schemas || echo "Schema registration failed or already done."
else
  echo "No schema registration script found. Skipping..."
fi

# Start main service
echo "Starting main application..."
exec "$@"
