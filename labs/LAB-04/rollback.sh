#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

if [ -f ".env" ]; then
    set -a
    # shellcheck disable=SC1091
    source ".env"
    set +a
fi

PREV_UI_IMAGE="${1:-${PREV_UI_IMAGE:-public.ecr.aws/aws-containers/retail-store-sample-ui:1.6.2}}"

echo "=== NovaShop Acil Rollback Başlatılıyor ==="
echo "Geri dönülecek stabil UI imajı: ${PREV_UI_IMAGE}"

UI_IMAGE="${PREV_UI_IMAGE}" docker compose -f docker-compose.prod.yml up -d ui

echo "Rollback tamamlandı. Konteyner durumu:"
docker compose -f docker-compose.prod.yml ps
