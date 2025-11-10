#!/bin/bash
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

# Use environment variables with defaults
# Map service-specific DB variables to generic ones
DB_HOST=${USER_DB_HOST:-${DB_HOST:-localhost}}
DB_PORT=${USER_DB_PORT:-${DB_PORT:-5432}}
PORT=${PORT:-8000}

echo "Waiting for database at $DB_HOST:$DB_PORT..."
while ! nc -z $DB_HOST $DB_PORT; do
  echo "Database not ready, waiting..."
  sleep 1
done
echo "Database started"

echo "Running migrations..."
python manage.py makemigrations --noinput
python manage.py migrate --noinput

echo "Collecting static files..."
python manage.py collectstatic --noinput

echo "Starting server on port $PORT..."
exec "$@"
