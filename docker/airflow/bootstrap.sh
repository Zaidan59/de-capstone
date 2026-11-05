#!/usr/bin/env bash
set -euo pipefail
export HOP_CONFIG_FOLDER=/opt/airflow/hop-config
mkdir -p "$HOP_CONFIG_FOLDER"
cd /opt/hop
if ! ./hop-conf.sh -pl | grep -q 'capstone-local'; then
  ./hop-conf.sh --project-create --project=capstone-local \
    --project-home=/opt/lab/workspace/hop-project
fi
if ! ./hop-conf.sh -el | grep -q 'docker-local'; then
  ./hop-conf.sh --environment-create --environment=docker-local \
    --environment-project=capstone-local --environment-purpose=Development \
    --environment-config-files=/opt/lab/workspace/hop-project/environments/docker-local.json
fi
exec airflow standalone
