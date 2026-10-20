#!/usr/bin/env bash
# NovaShop observability Compose helper.
# Reads local-only secrets from the repository-root .env file.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ENV_FILE="${NOVASHOP_ENV_FILE:-$REPO_ROOT/.env}"
COMPOSE_FILE="$REPO_ROOT/deploy/observability/docker-compose.observability.yml"

action="${1:-config}"
shift || true

if [[ ! -r "$ENV_FILE" ]]; then
  printf 'Local environment file not found: %s\nCopy config/project.env.example to .env, set GRAFANA_ADMIN_PASSWORD, and do not commit it.\n' "$ENV_FILE" >&2
  exit 2
fi

grafana_password="$(grep -E '^GRAFANA_ADMIN_PASSWORD=' "$ENV_FILE" | tail -n 1 | cut -d= -f2- || true)"
if [[ "${grafana_password:0:1}" == '"' && "${grafana_password: -1}" == '"' ]] || \
   [[ "${grafana_password:0:1}" == "'" && "${grafana_password: -1}" == "'" ]]; then
  grafana_password="${grafana_password:1:${#grafana_password}-2}"
fi

case "$grafana_password" in
  ''|'<'*'>'|CHANGE_ME|changeme|example|password)
    printf 'GRAFANA_ADMIN_PASSWORD is missing or a placeholder in %s; set a real local value before starting observability.\n' "$ENV_FILE" >&2
    exit 2
    ;;
esac

compose_args=(--env-file "$ENV_FILE" -p novashop-observability -f "$COMPOSE_FILE")

case "$action" in
  config)
    docker compose "${compose_args[@]}" config
    ;;
  up)
    docker compose "${compose_args[@]}" up --detach --wait "$@"
    ;;
  ps)
    docker compose "${compose_args[@]}" ps "$@"
    ;;
  down)
    docker compose "${compose_args[@]}" down "$@"
    ;;
  *)
    printf 'Usage: %s [config|up|ps|down] [docker compose options]\n' "$0" >&2
    exit 2
    ;;
esac
