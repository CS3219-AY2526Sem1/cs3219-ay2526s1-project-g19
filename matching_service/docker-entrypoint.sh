#!/bin/bash
set -e

# =============================================================================
# Fetch secrets from AWS Secrets Manager
# =============================================================================
if [ -n "$AWS_SECRET_NAME" ] && [ -n "$AWS_REGION" ]; then
    echo "[Secrets] Fetching from $AWS_SECRET_NAME..."

    SECRET_STRING=$(aws secretsmanager get-secret-value \
        --secret-id "$AWS_SECRET_NAME" \
        --region "$AWS_REGION" \
        --query 'SecretString' \
        --output text 2>/dev/null)

    if [ $? -eq 0 ] && [ -n "$SECRET_STRING" ]; then
        # Export variables from secret
        while IFS= read -r line; do
            # Skip empty lines and comments
            if [ -z "$line" ] || [[ "$line" =~ ^[[:space:]]*# ]]; then
                continue
            fi
            # Export the variable
            if [[ "$line" =~ ^[A-Za-z_][A-Za-z0-9_]*= ]]; then
                export "$line"
            fi
        done <<< "$SECRET_STRING"
        echo "[Secrets] ✓ Environment variables loaded"
    else
        echo "[Secrets] ⚠ Failed to fetch, using task definition env vars"
    fi
fi

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
