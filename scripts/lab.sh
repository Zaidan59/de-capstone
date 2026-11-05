#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
CMD="${1:-help}"
ARG="${2:-core}"
CORE=(postgres mysql workbench cloudbeaver)
secret() { od -An -N24 -tx1 /dev/urandom | tr -d ' \n'; }
init_env() {
  if [[ -f .env ]]; then echo 'Refusing to overwrite existing .env' >&2; exit 1; fi
  while IFS= read -r line || [[ -n "$line" ]]; do
    if [[ "$line" == *=__GENERATE__ ]]; then
      printf '%s=%s\n' "${line%%=*}" "$(secret)"
    else
      printf '%s\n' "$line"
    fi
  done < .env.example > .env
  echo 'Created .env with generated lab-only secrets. Do not commit or publish it.'
}
compose() { docker compose -f compose.yaml "$@"; }
compose_om() { docker compose -f compose.yaml -f compose/openmetadata.yaml "$@"; }
check_ready() {
  if [[ ! -f .env ]]; then echo 'Missing .env: run init' >&2; exit 1; fi
  if ! docker info >/dev/null 2>&1; then echo 'Docker Engine is not running' >&2; exit 1; fi
}
service_list() {
  case "$1" in
    core) echo "${CORE[*]}" ;;
    orchestration|m08) echo airflow ;;
    streaming|m09) echo 'kafka flink-jobmanager flink-taskmanager' ;;
    lakehouse|m10) echo spark ;;
    objectstore) echo minio ;;
    observability|m13) echo grafana ;;
    bi|m14) echo superset ;;
    identity) echo keycloak ;;
    metadata|m11) echo 'openmetadata-db openmetadata-search openmetadata-migrate openmetadata-server' ;;
    *) echo "Unknown module: $1" >&2; exit 2 ;;
  esac
}
case "$CMD" in
  init) init_env ;;
  up|start)
    check_ready
    if [[ "$ARG" == core ]]; then
      compose up -d --build "${CORE[@]}"
    elif [[ "$ARG" == metadata || "$ARG" == m11 ]]; then
      compose up -d "${CORE[@]}"
      compose_om --profile metadata up -d openmetadata-server
    else
      compose up -d "${CORE[@]}"
      read -r -a targets <<< "$(service_list "$ARG")"
      case "$ARG" in
        m08) profile=orchestration;; m09) profile=streaming;; m10) profile=lakehouse;;
        m13) profile=observability;; m14) profile=bi;; *) profile="$ARG";;
      esac
      compose --profile "$profile" up -d --build "${targets[@]}"
    fi
    ;;
  stop)
    check_ready
    if [[ "$ARG" == core ]]; then
      echo 'Stop optional modules before core; then run: docker compose stop postgres mysql workbench cloudbeaver'
      compose stop "${CORE[@]}"
    elif [[ "$ARG" == metadata || "$ARG" == m11 ]]; then
      compose_om --profile metadata stop openmetadata-server openmetadata-search openmetadata-db
    else
      read -r -a targets <<< "$(service_list "$ARG")"
      compose stop "${targets[@]}"
    fi
    ;;
  status|ps) check_ready; compose ps -a; if [[ "${ARG:-}" == metadata ]]; then compose_om --profile metadata ps -a; fi ;;
  preflight)
    check_ready
    echo '--- Container state ---'
    compose ps
    echo '--- PostgreSQL test (expected 60) ---'
    compose exec -T postgres psql -U labuser -d labdata -Atc 'SELECT COUNT(*) FROM raw.sales_orders;'
    echo '--- MySQL test (expected 3) ---'
    compose exec -T mysql sh -lc 'MYSQL_PWD="$MYSQL_PASSWORD" mysql -u "$MYSQL_USER" -D "$MYSQL_DATABASE" -N -e "SELECT COUNT(*) FROM demo_orders;"'
    echo '--- Workbench tools ---'
    compose exec -T workbench bash -lc 'python --version && java -version && codium --version | head -n 1 && test -f /opt/hop/hop-gui.sh && echo "Apache Hop files: present"'
    if command -v curl >/dev/null 2>&1; then
      echo '--- Web UIs ---'
      for url in "https://127.0.0.1:$(grep '^WORKBENCH_PORT=' .env | cut -d= -f2)" "http://127.0.0.1:$(grep '^CLOUDBEAVER_PORT=' .env | cut -d= -f2)"; do
        curl -k -sS -o /dev/null --max-time 10 -w '%{http_code} %{url_effective}\n' "$url" || true
      done
    fi
    echo 'Open Workbench HTTPS (self-signed) and CloudBeaver HTTP in your own browser.'
    ;;
  hop-setup)
    check_ready
    compose exec -T -u abc workbench /usr/local/bin/hop-setup
    ;;
  hop-demo)
    check_ready
    compose exec -T -u abc workbench /usr/local/bin/hop-setup
    compose exec -T -u abc workbench bash -lc \
      'cd /opt/hop && ./hop-run.sh -j capstone-local -e docker-local -r local -f /config/workspace/hop-project/workflows/wf_load_sales.hwf'
    compose exec -T postgres psql -U labuser -d labdata -Atc 'SELECT COUNT(*) FROM stg.sales_orders;'
    ;;
  seed)
    check_ready
    compose exec -T postgres psql -U labuser -d labdata -f /docker-entrypoint-initdb.d/02-demo.sql
    ;;
  backup)
    check_ready
    mkdir -p backups
    stamp="$(date +%Y%m%d_%H%M%S)"
    compose exec -T postgres pg_dump -U labuser -d labdata --no-owner --no-privileges > "backups/labdata_${stamp}.sql"
    echo "Saved backups/labdata_${stamp}.sql"
    ;;
  reset-demo)
    check_ready
    echo 'Resetting only the synthetic sales staging/warehouse, not volumes or capstone project files.'
    compose exec -T postgres psql -U labuser -d labdata -c 'TRUNCATE stg.sales_orders, mart.daily_sales;'
    compose exec -T postgres psql -U labuser -d labdata -f /docker-entrypoint-initdb.d/02-demo.sql
    ;;
  logs)
    check_ready
    compose logs --tail=120 "${ARG}" ;;
  shell)
    check_ready
    compose exec -u abc workbench bash ;;
  config)
    check_ready
    if [[ "$ARG" == metadata ]]; then compose_om --profile metadata config --quiet; else compose config --quiet; fi
    ;;
  destroy)
    check_ready
    read -r -p 'Type DELETE to remove containers AND ALL PERSISTENT NAMED VOLUMES: ' confirm
    [[ "$confirm" == DELETE ]] || { echo 'Cancelled'; exit 1; }
    compose_om --profile metadata down --volumes --remove-orphans
    ;;
  help|-h|--help)
    cat <<'EOF'
Data Engineering Capstone Lab - Linux / Git Bash
  ./scripts/lab.sh init
  ./scripts/lab.sh up core
  ./scripts/lab.sh up orchestration|streaming|lakehouse|metadata|observability|bi|identity|objectstore
  ./scripts/lab.sh preflight
  ./scripts/lab.sh hop-setup / hop-demo
  ./scripts/lab.sh status / status metadata
  ./scripts/lab.sh stop streaming
  ./scripts/lab.sh backup / seed / reset-demo / shell / logs <service>
  ./scripts/lab.sh config / config metadata
  ./scripts/lab.sh destroy     (DESTRUCTIVE, prompts confirmation)
EOF
    ;;
  *) echo "Unknown command $CMD" >&2; exit 2 ;;
esac
