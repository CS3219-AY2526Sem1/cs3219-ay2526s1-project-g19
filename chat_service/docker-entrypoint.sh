#!/bin/sh
set -e

fetch_aws_secrets() {
    if [ -z "$AWS_SECRET_NAME" ] || [ -z "$AWS_REGION" ]; then
        echo "[Secrets] AWS_SECRET_NAME or AWS_REGION not set, skipping fetch"
        return
    fi

    echo "[Secrets] Fetching env vars from $AWS_SECRET_NAME in $AWS_REGION..."
    if ! SECRET_STRING=$(aws secretsmanager get-secret-value \
        --secret-id "$AWS_SECRET_NAME" \
        --region "$AWS_REGION" \
        --query 'SecretString' \
        --output text 2>/dev/null); then
        echo "[Secrets] ⚠ Failed to fetch secret payload"
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

def emit(pairs):
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
    kv_pairs = []
    for line in secret.splitlines():
        stripped = line.strip()
        if not stripped or stripped.startswith("#") or "=" not in stripped:
            continue
        key, value = stripped.split("=", 1)
        kv_pairs.append((key, value))
    emit(kv_pairs)
else:
    if isinstance(data, dict):
        emit(data.items())
PY

    if [ -s "${tmp_export_file}" ]; then
        # shellcheck disable=SC1090
        . "${tmp_export_file}"
        echo "[Secrets] ✓ Loaded environment variables from Secrets Manager"
    else
        echo "[Secrets] ⚠ Secret fetched but no exports generated"
    fi

    rm -f "${tmp_export_file}"
    unset SECRET_STRING
}

fetch_aws_secrets

echo "[Chat Service] Starting server..."
exec "$@"
