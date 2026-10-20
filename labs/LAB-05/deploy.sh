#!/usr/bin/env bash
# ==============================================================================
# NovaShop LAB-05: EC2 Dağıtım ve Otomatik Rollback Betiği (Docker Hub)
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

NEW_IMAGE="${1:-}"
if [ -z "$NEW_IMAGE" ]; then
    echo "❌ Hata: İmaj parametresi eksik! Kullanım: ./deploy.sh <DOCKERHUB_USERNAME/novashop-ui:TAG>" >&2
    exit 1
fi

COMPOSE_FILE="${COMPOSE_FILE:-docker-compose.prod.yml}"
if [ ! -f "$COMPOSE_FILE" ]; then
    echo "❌ Hata: $COMPOSE_FILE bulunamadı!" >&2
    exit 1
fi

echo "=== 1. Mevcut Stabil İmajı Tespit Etme ==="
CURRENT_IMAGE=$(grep -oE "image: .*novashop-ui:[^ \"']+" "$COMPOSE_FILE" | awk '{print $2}' || true)
if [ -z "$CURRENT_IMAGE" ] || [ "$CURRENT_IMAGE" = "novashop-ui:latest" ]; then
    CURRENT_IMAGE="public.ecr.aws/aws-containers/retail-store-sample-ui:1.6.2"
fi
echo "Mevcut stabil imaj: $CURRENT_IMAGE"

echo "=== 2. Yeni İmajı Docker Hub'dan Çekme ==="
echo "İmaj indiriliyor: $NEW_IMAGE"
docker pull "$NEW_IMAGE"

echo "=== 3. $COMPOSE_FILE Güncelleniyor ==="
sed -i.bak -E "s|image: .*novashop-ui:[^ \"']+|image: ${NEW_IMAGE}|g" "$COMPOSE_FILE"
rm -f "${COMPOSE_FILE}.bak" 2>/dev/null || true

echo "=== 4. Konteynerler Başlatılıyor ==="
docker compose -f "$COMPOSE_FILE" up -d

echo "=== 5. Sağlık Kontrolü (Smoke Test) ==="
SUCCESS=0
for i in $(seq 1 15); do
    STATUS=$(curl -s http://127.0.0.1:8888/actuator/health | grep -o '"status":"UP"' || true)
    if [ "$STATUS" = '"status":"UP"' ]; then
        echo "✅ Sağlık kontrolü BAŞARILI ($i/15): $STATUS"
        SUCCESS=1
        break
    fi
    echo "   Servis bekleniyor ($i/15)..."
    sleep 4
done

if [ "$SUCCESS" -ne 1 ]; then
    echo "❌ HATA: Sağlık kontrolü başarısız oldu! Otomatik Rollback başlatılıyor..." >&2
    echo "Önceki stabil sürüme dönülüyor: $CURRENT_IMAGE"
    sed -i.bak -E "s|image: .*novashop-ui:[^ \"']+|image: ${CURRENT_IMAGE}|g" "$COMPOSE_FILE"
    rm -f "${COMPOSE_FILE}.bak" 2>/dev/null || true
    docker compose -f "$COMPOSE_FILE" up -d ui
    echo "✅ Rollback tamamlandı: $CURRENT_IMAGE yeniden devrede."
    exit 1
fi

echo "=== 🎉 Dağıtım Başarıyla Tamamlandı ==="
