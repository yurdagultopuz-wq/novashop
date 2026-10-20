#!/usr/bin/env bash
# NovaShop 3-Tier Compose Helper
# Enforces the 3tier.secure.yml hardening overlay.
set -euo pipefail

action="${1:-config}"
shift || true

case "$action" in
  config)
    docker compose \
      -f src/ui/docker-compose.yml \
      -f deploy/compose/3tier.secure.yml \
      config
    ;;
  up)
    docker compose -p novashop-3tier \
      -f src/ui/docker-compose.yml \
      -f deploy/compose/3tier.secure.yml \
      up --build --detach --wait "$@"
    ;;
  down)
    docker compose -p novashop-3tier \
      -f src/ui/docker-compose.yml \
      -f deploy/compose/3tier.secure.yml \
      down "$@"
    ;;
  *)
    printf 'Usage: %s [config|up|down] [docker compose options]\n' "$0" >&2
    exit 2
    ;;
esac
