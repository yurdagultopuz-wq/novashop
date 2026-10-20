#!/usr/bin/env bash
# ==============================================================================
# NovaShop LAB-05: Acil Geri Alma (Rollback) Betiği
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

COMPOSE_FILE="${COMPOSE_FILE:-docker-compose.prod.yml}"
TARGET_IMAGE="${1:-public.ecr.aws/aws-containers/retail-store-sample-ui:1.6.2}"

echo "=== NovaShop Acil Rollback Başlatılıyor ==="
echo "Geri dönülecek hedef imaj: $TARGET_IMAGE"

sed -i.bak -E "s|image: .*novashop-ui:[^ \"']+|image: ${TARGET_IMAGE}|g" "$COMPOSE_FILE"
rm -f "${COMPOSE_FILE}.bak" 2>/dev/null || true

docker compose -f "$COMPOSE_FILE" up -d ui

echo "Rollback tamamlandı. Konteyner durumu:"
docker compose -f "$COMPOSE_FILE" ps
