#!/usr/bin/env bash
# NovaShop Full-Stack Compose Helper
# Enforces the full.secure.yml security overlay and prevents empty/placeholder database secrets.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

action="${1:-config}"
shift || true
ENV_FILE="${NOVASHOP_ENV_FILE:-$REPO_ROOT/.env}"

if [[ ! -r "$ENV_FILE" ]]; then
  printf 'Local environment file not found: %s\nCopy config/project.env.example to .env, set DB_PASSWORD, and do not commit it.\n' "$ENV_FILE" >&2
  exit 2
fi

db_password="$(grep -E '^DB_PASSWORD=' "$ENV_FILE" | tail -n 1 | cut -d= -f2- || true)"
if [[ "${db_password:0:1}" == '"' && "${db_password: -1}" == '"' ]] || \
   [[ "${db_password:0:1}" == "'" && "${db_password: -1}" == "'" ]]; then
  db_password="${db_password:1:${#db_password}-2}"
fi

case "$db_password" in
  ''|'<'*'>'|CHANGE_ME|changeme|example|password|REPLACE_WITH_SECRETS_MANAGER_GENERATED_PASSWORD)
    printf 'DB_PASSWORD is missing or a placeholder in %s; set a real local value before using full Compose.\n' "$ENV_FILE" >&2
    exit 2
    ;;
esac

compose_args=(
  --env-file "$ENV_FILE"
  -p novashop-full
  -f src/app/docker-compose.yml
  -f src/app/compose.override.yaml
  -f deploy/compose/full.secure.yml
)

case "$action" in
  config)
    # Validate without printing resolved environment values, which can contain a secret.
    docker compose "${compose_args[@]}" config --quiet
    ;;
  up)
    docker compose "${compose_args[@]}" up --build --detach --wait "$@"
    ;;
  down)
    docker compose "${compose_args[@]}" down "$@"
    ;;
  *)
    printf 'Usage: %s [config|up|down] [docker compose options]\n' "$0" >&2
    exit 2
    ;;
esac
