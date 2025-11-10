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

# Map service-specific DB variables to generic ones
DB_HOST=${QUESTION_DB_HOST:-${DB_HOST:-localhost}}
DB_PORT=${QUESTION_DB_PORT:-${DB_PORT:-5432}}
PORT=${PORT:-8000}

register_schemas() {
  if [ -f "question_service/kafka/scripts/register_schemas.py" ]; then
    echo "Registering Kafka schemas..."
    python -m question_service.kafka.scripts.register_schemas || echo "Schema registration failed or already done."
  else
    echo "No schema registration script found. Skipping schema registration..."
  fi
}

wait_for_db() {
  echo "Waiting for database at ${DB_HOST}:${DB_PORT}..."
  while ! nc -z "${DB_HOST}" "${DB_PORT}"; do
    echo "Database not ready, waiting..."
    sleep 1
  done
  echo "Database available."
}

run_migrations() {
  echo "Running migrations..."
  python manage.py migrate --noinput
  echo "Collecting static files..."
  python manage.py collectstatic --noinput
}

main() {
  register_schemas

  if [ "${SKIP_DB_SETUP}" != "true" ]; then
    wait_for_db
    run_migrations
  else
    echo "SKIP_DB_SETUP is true; skipping migrations and collectstatic."
  fi

  echo "Starting main application..."
  exec "$@"
}

main "$@"
