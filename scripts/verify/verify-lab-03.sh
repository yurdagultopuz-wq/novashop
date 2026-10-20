#!/usr/bin/env bash
# NovaShop — LAB-03 Docker ve Docker Compose Doğrulama Betiği
# Canlı smoke kontrolleri zorunludur; başarısızlık durumunda fail-fast (exit 1) verir.
set -euo pipefail

PORT="${1:-8888}"
HOST="${2:-localhost}"
MODE="${3:-live}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Eğer ilk parametre --config-only ise statik denetim moduna geç
if [ "$PORT" = "--config-only" ] || [ "$PORT" = "--static" ]; then
    MODE="config-only"
    PORT="8888"
fi

echo "=== [LAB-03] Doğrulama Başlatılıyor (${HOST}:${PORT} | Mod: ${MODE}) ==="

# 1. Compose Güvenlik Overlay Dosyası Kontrolü
OVERLAY_FILE="$REPO_ROOT/deploy/compose/starter.secure.yml"
if [ ! -f "$OVERLAY_FILE" ]; then
    echo "❌ HATA: Güvenlik overlay dosyası bulunamadı ($OVERLAY_FILE)." >&2
    exit 1
fi
echo "✅ Güvenlik overlay dosyası mevcut ($OVERLAY_FILE)."

# 2. Overlay İçi Güvenlik Sertleştirmeleri Kontrolü
TARGET_OVERLAY="$OVERLAY_FILE"

grep -q "read_only: true" "$TARGET_OVERLAY" || { echo "❌ HATA: Overlay içinde read_only: true eksik." >&2; exit 1; }
grep -q "no-new-privileges:true" "$TARGET_OVERLAY" || { echo "❌ HATA: Overlay içinde no-new-privileges:true eksik." >&2; exit 1; }
grep -q "pids_limit" "$TARGET_OVERLAY" || { echo "❌ HATA: Overlay içinde pids_limit eksik." >&2; exit 1; }
grep -q "cpus" "$TARGET_OVERLAY" || { echo "❌ HATA: Overlay içinde cpus limiti eksik." >&2; exit 1; }
echo "✅ Overlay güvenlik sertleştirmeleri (read-only, no-new-privileges, CPU/PID limits) doğrulandı."

# 3. Dockerfile Non-root (appuser / UID 1000) Kontrolü
DOCKERFILE="$REPO_ROOT/src/ui/Dockerfile"
if [ -f "$DOCKERFILE" ]; then
    grep -q "USER appuser" "$DOCKERFILE" || { echo "❌ HATA: Dockerfile içinde USER appuser direktifi eksik." >&2; exit 1; }
    echo "✅ Dockerfile non-root kullanıcı direktifi (USER appuser) doğrulandı."
fi

# Statik / Config-only modunda canlı HTTP kontrolleri atlanır
if [ "$MODE" = "config-only" ]; then
    echo "ℹ️ Mod: config-only. Canlı HTTP kontrolleri atlandı."
    echo "=== [LAB-03] Yapılandırma Doğrulaması Başarılı (PASS) ==="
    exit 0
fi

# 4. Canlı Konteyner HTTP Sağlık Kontrolü (/actuator/health)
echo "4. Canlı konteyner Actuator sağlık kontrolü test ediliyor..."
HEALTH_BODY=$(curl -s --connect-timeout 5 "http://${HOST}:${PORT}/actuator/health" 2>/dev/null || echo "")

if echo "$HEALTH_BODY" | grep -q '"status":"UP"'; then
    echo "✅ Sağlık kontrolü başarılı: $HEALTH_BODY"
else
    echo "❌ HATA: http://${HOST}:${PORT}/actuator/health erişilemedi veya durum 'UP' değil!" >&2
    echo "   Dönen yanıt: '$HEALTH_BODY'" >&2
    echo "   (Konteyneri başlattığınızdan emin olun: bash scripts/compose-starter.sh up)" >&2
    exit 1
fi

# 5. NovaShop Marka Başlığı Kontrolü
echo "5. NovaShop marka kimliği test ediliyor..."
BRAND_BODY=$(curl -s --connect-timeout 5 "http://${HOST}:${PORT}/" 2>/dev/null || echo "")
if echo "$BRAND_BODY" | grep -q "NovaShop DevOps Store"; then
    echo "✅ Marka başlığı doğrulandı: 'NovaShop DevOps Store'"
else
    echo "❌ HATA: Ana sayfada 'NovaShop DevOps Store' marka başlığı bulunamadı!" >&2
    exit 1
fi

# 6. Favicon Kontrolü
echo "6. Favicon HTTP 200 kontrolü..."
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 "http://${HOST}:${PORT}/favicon.ico" 2>/dev/null || echo "000")
if [ "$HTTP_CODE" = "200" ]; then
    echo "✅ Favicon HTTP 200 OK."
else
    echo "❌ HATA: Favicon HTTP $HTTP_CODE döndü (Beklenen: 200)!" >&2
    exit 1
fi

echo "=== [LAB-03] Canlı Smoke ve Güvenlik Doğrulaması Başarılı (PASS) ==="
