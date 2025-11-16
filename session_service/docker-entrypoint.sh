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

def normalize_value(value):
    value = str(value).strip()
    if len(value) >= 2 and value[0] == value[-1] and value[0] in {"'", '"'}:
        value = value[1:-1]
    return value

def emit_from_pairs(pairs):
    for key, value in pairs:
        key = key.strip()
        if not valid_key.match(key):
            continue
        cleaned_value = normalize_value(value)
        print(f"export {key}={shlex.quote(cleaned_value)}")

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

normalize_bool_var() {
    var_name=$1
    value=$(eval "printf '%s' \"\${$var_name:-}\"" | tr -d '\r' | tr '[:upper:]' '[:lower:]')
    case "$value" in
        true|1|yes|on)
            export "$var_name"=true
            ;;
        false|0|no|off)
            export "$var_name"=false
            ;;
    esac
}

normalize_bool_var "SKIP_DB_SETUP"

if [ -n "$SESSION_DB_SSL_MODE" ]; then
    raw_mode=$SESSION_DB_SSL_MODE
    cleaned_mode=$(printf '%s' "$raw_mode" | tr -d '\r' | tr '[:upper:]' '[:lower:]')
    case "$cleaned_mode" in
        disable|allow|prefer|require|verify-ca|verify-full)
            export SESSION_DB_SSL_MODE=$cleaned_mode
            ;;
        *)
            echo "[DB] ⚠ Invalid SESSION_DB_SSL_MODE='${raw_mode}', defaulting to 'require'"
            export SESSION_DB_SSL_MODE=require
            ;;
    esac
fi

if [ -n "$SERVICE_PREFIX_OVERRIDE" ]; then
    export SERVICE_PREFIX="$SERVICE_PREFIX_OVERRIDE"
    echo "[Config] SERVICE_PREFIX overridden to $SERVICE_PREFIX"
fi

is_consumer_command=false
for arg in "$@"; do
    case "$arg" in
        kafka.consumers.*)
            is_consumer_command=true
            break
            ;;
    esac
done

echo "is_consumer_command=$is_consumer_command"
echo "SKIP_DB_SETUP=$SKIP_DB_SETUP"
if [ "$is_consumer_command" = true ] && [ "$SKIP_DB_SETUP" != "true" ]; then
    export SKIP_DB_SETUP=true
    echo "[Config] Detected Kafka consumer command. Forcing SKIP_DB_SETUP=true (was '${SKIP_DB_SETUP:-unset}')."
fi

# Register kafka schema registry schemas
if [ -f "kafka/scripts/register_schemas.py" ]; then
  echo "Registering Kafka schemas..."
  python -m kafka.scripts.register_schemas || echo "Schema registration failed or already done."
else
  echo "No schema registration script found. Skipping..."
fi

DB_HOST=${SESSION_DB_HOST:-session_db}
DB_PORT=${SESSION_DB_PORT:-5432}

wait_for_db() {
  echo "Waiting for database at ${DB_HOST}:${DB_PORT}..."
  python - <<'PY'
import os, socket, time, sys

host = os.environ.get("SESSION_DB_HOST", "session_db")
port = int(os.environ.get("SESSION_DB_PORT", "5432"))
timeout = time.time() + 60

while True:
    try:
        with socket.create_connection((host, port), timeout=2):
            print("Database available.")
            break
    except OSError:
        if time.time() > timeout:
            print(f"ERROR: Database not reachable at {host}:{port}", file=sys.stderr)
            sys.exit(1)
        time.sleep(1)
PY
}

echo "value of skip_db_setup is ${SKIP_DB_SETUP}"
if [ "${SKIP_DB_SETUP}" != "true" ]; then
  echo "[DB] SESSION_DB_HOST=${SESSION_DB_HOST:-session_db}"
  echo "[DB] SESSION_DB_PORT=${SESSION_DB_PORT:-5432}"
  echo "[DB] SESSION_DB_SSL_MODE=${SESSION_DB_SSL_MODE:-<unset>}"
  echo "[DB] SESSION_DB_PASSWORD=${SESSION_DB_PASSWORD}"
  wait_for_db
  echo "Running migrations..."

  alembic upgrade head
else
  echo "SKIP_DB_SETUP=true, skipping migrations."
fi

# Start Kafka consumers in background
echo "Starting Kafka question_chosen consumer..."
python -m kafka.consumers.question_chosen &
QUESTION_CHOSEN_PID=$!
echo "Question chosen consumer started with PID $QUESTION_CHOSEN_PID"

echo "Starting Kafka session_end consumer..."
python -m kafka.consumers.session_end &
SESSION_END_PID=$!
echo "Session end consumer started with PID $SESSION_END_PID"

# start app
exec "$@"
