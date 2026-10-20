#!/usr/bin/env bash
# NovaShop UI Starter Compose Helper
# Enforces the starter.secure.yml hardening overlay.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

action="${1:-config}"
shift || true

case "$action" in
  config)
    docker compose \
      -f src/ui/docker-compose.yml \
      -f deploy/compose/starter.secure.yml \
      config
    ;;
  up)
    docker compose -p novashop-starter \
      -f src/ui/docker-compose.yml \
      -f deploy/compose/starter.secure.yml \
      up --build --detach --wait "$@"
    ;;
  down)
    docker compose -p novashop-starter \
      -f src/ui/docker-compose.yml \
      -f deploy/compose/starter.secure.yml \
      down "$@"
    ;;
  *)
    printf 'Usage: %s [config|up|down] [docker compose options]\n' "$0" >&2
    exit 2
    ;;
esac
