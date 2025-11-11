#!/bin/sh
set -e

TEMPLATE_PATH=${TEMPLATE_PATH:-/etc/nginx/templates/default.conf.template}
OUTPUT_PATH=${OUTPUT_PATH:-/etc/nginx/conf.d/default.conf}

render_nginx_config() {
  python3 - <<'PY'
import os
from pathlib import Path

template_path = Path(os.environ.get("TEMPLATE_PATH", "/etc/nginx/templates/default.conf.template"))
output_path = Path(os.environ.get("OUTPUT_PATH", "/etc/nginx/conf.d/default.conf"))

keys = [
    "NGINX_USER_SERVICE_HOST",
    "NGINX_QUESTION_SERVICE_HOST",
    "NGINX_MATCHING_SERVICE_HOST",
    "NGINX_HISTORY_SERVICE_HOST",
    "NGINX_SESSION_SERVICE_HOST",
    "NGINX_COLLABORATION_SERVICE_HOST",
    "NGINX_CHAT_SERVICE_HOST",
    "NGINX_EXECUTION_SERVICE_HOST",
]

template = template_path.read_text()
missing = []

for key in keys:
    value = os.environ.get(key)
    if value is None:
        missing.append(key)
        value = ""
    template = template.replace("${%s}" % key, value)

output_path.write_text(template)

if missing:
    print(f"[frontend] WARNING: missing env vars: {', '.join(missing)}", flush=True)
else:
    print("[frontend] Successfully rendered nginx config.", flush=True)
PY
}

echo "Substituting environment variables in nginx configuration..."
render_nginx_config

echo "Generated nginx configuration:"
cat "$OUTPUT_PATH"

echo "Testing nginx configuration..."
nginx -t

echo "Starting nginx..."
exec nginx -g "daemon off;"
