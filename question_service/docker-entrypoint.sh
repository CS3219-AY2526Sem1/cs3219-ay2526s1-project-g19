#!/bin/bash
# Question Service Docker Entrypoint
#
# This script automatically:
# 1. Registers Kafka schemas (if Kafka is configured)
# 2. Waits for database to be ready
# 3. Runs Django migrations
# 4. Collects static files
# 5. Loads fixture data (if enabled and database is empty)
# 6. Publishes initial topics/difficulties to Kafka (after migrations, every start)
#
# Environment Variables:
#   - SKIP_DB_SETUP: Skip database setup steps (default: false)
#   - LOAD_FIXTURES: Load fixture data (default: true)
#                    Set to "false" or "0" to skip loading
#                    Set to "force" to load even if database has data
#   - FIXTURE_FILE: Path to fixture file (default: fixtures/mock_1042_9_oct.json)
#   - SKIP_KAFKA_SETUP: Skip Kafka topics/difficulties publishing (default: false)

set -e

load_aws_secrets() {
    if [ -z "$AWS_SECRET_NAME" ] || [ -z "$AWS_REGION" ]; then
        return
    fi

    echo "[Secrets] Fetching from $AWS_SECRET_NAME..."

    SECRET_STRING=$(aws secretsmanager get-secret-value \
        --secret-id "$AWS_SECRET_NAME" \
        --region "$AWS_REGION" \
        --query 'SecretString' \
        --output text 2>/dev/null)

    if [ $? -ne 0 ] || [ -z "$SECRET_STRING" ]; then
        echo "[Secrets] ⚠ Failed to fetch, using task definition env vars"
        return
    fi

    export SECRET_STRING
    tmp_export_file=$(mktemp)

    python - <<'PY' > "${tmp_export_file}"
import json
import os
import re
import shlex

secret = os.environ.get("SECRET_STRING", "").strip()
valid_key = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*$")

def emit_from_pairs(pairs):
    for key, value in pairs:
        key = key.strip()
        if not valid_key.match(key):
            continue
        print(f"export {key}={shlex.quote(str(value).strip())}")

if not secret:
    raise SystemExit

try:
    data = json.loads(secret)
except json.JSONDecodeError:
    pairs = []
    for line in secret.splitlines():
        stripped = line.strip()
        if not stripped or stripped.startswith("#") or "=" not in stripped:
            continue
        key, value = stripped.split("=", 1)
        pairs.append((key, value))
    emit_from_pairs(pairs)
else:
    if isinstance(data, dict):
        emit_from_pairs(data.items())
PY

    if [ -s "${tmp_export_file}" ]; then
        # shellcheck source=/dev/null
        . "${tmp_export_file}"
        echo "[Secrets] ✓ Environment variables loaded"
    else
        echo "[Secrets] ⚠ Secret fetched but no variables exported"
    fi

    rm -f "${tmp_export_file}"
    unset SECRET_STRING
}

load_aws_secrets

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
  echo "Initializing database with mock data if empty..."
  python manage.py init_data
}

check_database_empty() {
  echo "Checking if database is empty..."
  # Check if there are any questions in the database
  # Returns 0 (true) if database is empty, 1 (false) if it has data
  python -c "
import sys
import os
import django

try:
    os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'question_service.settings')
    django.setup()
    from question_service.models import Question
    count = Question.objects.count()
    sys.exit(0 if count == 0 else 1)
except Exception:
    # If we can't check (e.g., tables don't exist yet), assume empty
    sys.exit(0)
" > /dev/null 2>&1
  return $?
}

load_fixtures() {
  FIXTURE_FILE="${FIXTURE_FILE:-fixtures/mock_1042_9_oct.json}"
  
  if [ ! -f "${FIXTURE_FILE}" ]; then
    echo "Fixture file ${FIXTURE_FILE} not found. Skipping fixture loading..."
    return 0
  fi

  # Check if we should load fixtures
  if [ "${LOAD_FIXTURES}" = "false" ] || [ "${LOAD_FIXTURES}" = "0" ]; then
    echo "LOAD_FIXTURES is false; skipping fixture loading."
    return 0
  fi

  # If LOAD_FIXTURES is not explicitly set to "force", check if DB is empty
  if [ "${LOAD_FIXTURES}" != "force" ]; then
    if ! check_database_empty; then
      echo "Database already contains data. Skipping fixture loading."
      echo "To force reload, set LOAD_FIXTURES=force"
      return 0
    fi
  fi

  echo "Loading fixture data from ${FIXTURE_FILE}..."
  if python manage.py loaddata "${FIXTURE_FILE}"; then
    echo "Successfully loaded fixture data."
  else
    echo "Warning: Failed to load fixture data. Continuing anyway..."
  fi
}

publish_initial_kafka() {
  if [ "${SKIP_KAFKA_SETUP}" = "true" ]; then
    echo "SKIP_KAFKA_SETUP is true; skipping Kafka publication."
    return 0
  fi
  echo "Publishing topics and difficulties to Kafka..."
  # This command will compute current topics/difficulties from DB and publish
  python manage.py setup_kafka --publish-only || echo "Kafka publish failed or not configured. Continuing..."
}

main() {
  register_schemas

  if [ "${SKIP_DB_SETUP}" != "true" ]; then
    wait_for_db
    run_migrations
    load_fixtures
    # Always publish on every container start after migrations
    publish_initial_kafka
  else
    echo "SKIP_DB_SETUP is true; skipping migrations, collectstatic, and fixture loading."
  fi

  # Start Kafka consumer in background
  echo "Starting Kafka consumer in background..."
  python manage.py run_question_consumer &
  CONSUMER_PID=$!
  echo "Kafka consumer started with PID $CONSUMER_PID"

  echo "Starting main application..."
  exec "$@"
}

main "$@"
