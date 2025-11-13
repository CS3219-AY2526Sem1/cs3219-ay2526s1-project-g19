#!/bin/sh
set -e

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

if [ "${SKIP_DB_SETUP}" != "true" ]; then
  wait_for_db
  echo "Running migrations..."
  alembic upgrade head
else
  echo "SKIP_DB_SETUP=true, skipping migrations."
fi

# start app
exec "$@"
