#!/usr/bin/env bash
# NovaShop — AWS 3-Tier Otomatik Dağıtım ve Sağlık Doğrulama Betiği
set -euo pipefail

NEW_TAG="${1:-v0.1.0}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "=== [NovaShop 3-Tier] Dağıtım Başlatılıyor (Hedef Etiket: ${NEW_TAG}) ==="

cd "$REPO_ROOT"

# 1. Ortam Değişkeni (.env) Dosyası Kontrolü
if [ ! -f ".env" ] && [ ! -f "deploy/compose/.env" ]; then
    echo "⚠️ UYARI: .env dosyası bulunamadı. deploy/compose/.env.3tier.example şablonundan oluşturuluyor..."
    cp deploy/compose/.env.3tier.example .env
fi

# 2. Önceki Stabil İmaj Etiketini Yedekle
PREV_TAG_FILE=".prev_ui_tag"
if [ -f "$PREV_TAG_FILE" ]; then
    PREV_TAG=$(cat "$PREV_TAG_FILE")
else
    PREV_TAG="v0.1.0"
fi
echo "ℹ️ Mevcut stabil sürüm: $PREV_TAG"
echo "$NEW_TAG" > "$PREV_TAG_FILE"

# 3. Docker Compose ile 3-Tier Yığınını Başlat
echo "3. Docker Compose 3-Tier yığını güncelleniyor..."
if command -v docker >/dev/null 2>&1; then
    docker compose -p novashop-3tier \
      -f src/ui/docker-compose.yml \
      -f deploy/compose/3tier.secure.yml \
      up -d --wait --remove-orphans
else
    echo "ℹ️ Bilgi: Docker CLI mevcut değil; simülasyon ortamındasınız."
fi

# 4. Sağlık Kontrolü (Smoke Health Check)
echo "4. Dağıtım sonrası Actuator sağlık kontrolü bekleniyor..."
MAX_ATTEMPTS=15
ATTEMPT=0
HEALTHY=false

while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
    ATTEMPT=$((ATTEMPT + 1))
    echo "   Kontrol ediliyor ($ATTEMPT/$MAX_ATTEMPTS)..."
    
    HEALTH_STATUS=$(curl -s --connect-timeout 2 "http://127.0.0.1:8888/actuator/health" 2>/dev/null || echo "")
    if echo "$HEALTH_STATUS" | grep -q '"status":"UP"'; then
        HEALTHY=true
        break
    fi
    sleep 2
done

# 5. Başarı veya Otomatik Rollback Kararı
if [ "$HEALTHY" = true ]; then
    echo "✅ Dağıtım Başarılı: NovaShop 3-Tier servisi UP durumunda!"
    echo "=== [NovaShop 3-Tier] Dağıtım Tamamlandı ==="
    exit 0
else
    echo "❌ HATA: Sağlık kontrolü zaman aşımına uğradı! Otomatik Rollback tetikleniyor..." >&2
    bash "$SCRIPT_DIR/rollback-3tier.sh" "$PREV_TAG"
    exit 1
fi
