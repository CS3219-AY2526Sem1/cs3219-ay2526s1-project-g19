#!/bin/sh
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
        echo "[Debug] KAFKA_BOOTSTRAP_SERVERS=$KAFKA_BOOTSTRAP_SERVERS"
    else
        echo "[Secrets] ⚠ Secret fetched but no variables exported"
    fi

    rm -f "${tmp_export_file}"
    unset SECRET_STRING
}

load_aws_secrets

echo "Starting matching service container..."

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
