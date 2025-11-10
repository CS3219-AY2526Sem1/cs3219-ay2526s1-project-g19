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

# Run migrations
echo "Running migrations..."
python manage.py migrate --noinput

# Start server
echo "Starting execution service on port ${PORT:-8000}..."
exec "$@"
