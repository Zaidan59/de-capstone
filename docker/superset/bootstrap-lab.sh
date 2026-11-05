#!/usr/bin/env bash
set -euo pipefail
superset db upgrade
superset fab create-admin --username "${SUPERSET_ADMIN_USERNAME:-admin}" \
  --firstname Data --lastname Engineer --email admin@example.invalid \
  --password "${SUPERSET_ADMIN_PASSWORD}" || true
superset init
exec gunicorn -w 2 -k gthread --threads 4 --timeout 120 \
  -b 0.0.0.0:8088 'superset.app:create_app()'
