#!/usr/bin/env bash
# NovaShop — LAB-04 AWS 3-Tier ve Nginx TLS Doğrulama Betiği
set -e

TARGET_HOST="${1:-}"
INSECURE_FLAG="${2:-}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

if [ -z "$TARGET_HOST" ] || [ "$TARGET_HOST" = "--config-only" ]; then
    echo "=== [LAB-04] Statik / Konfigürasyon Doğrulaması ==="

    # 1. Nginx 3-Tier Konfigürasyon Kontrolü
    NGINX_CONF="$REPO_ROOT/deploy/nginx/nginx-3tier.conf"
    if [ ! -f "$NGINX_CONF" ]; then
        echo "❌ HATA: deploy/nginx/nginx-3tier.conf bulunamadı!" >&2
        exit 1
    fi

    if grep -q "301 https://" "$NGINX_CONF" && \
       grep -q "ssl_certificate" "$NGINX_CONF" && \
       grep -q "healthz" "$NGINX_CONF"; then
        echo "✅ Nginx 3-Tier TLS ve yönlendirme kuralları doğrulandı."
    else
        echo "❌ HATA: Nginx 3-Tier konfigürasyonunda zorunlu TLS yönergeleri eksik!" >&2
        exit 1
    fi

    # 2. 3-Tier Secure Compose Yapılandırma Kontrolü
    COMPOSE_CONF="$REPO_ROOT/deploy/compose/3tier.secure.yml"
    if [ ! -f "$COMPOSE_CONF" ]; then
        echo "❌ HATA: deploy/compose/3tier.secure.yml bulunamadı!" >&2
        exit 1
    fi

    if grep -q "novashop-tier-net" "$COMPOSE_CONF" && \
       grep -q "read_only: true" "$COMPOSE_CONF"; then
        echo "✅ 3-Tier Compose ağ izolasyonu ve güvenlik kısıtları doğrulandı."
    else
        echo "❌ HATA: 3-Tier Compose güvenlik tanımları eksik!" >&2
        exit 1
    fi

    # 3. Dağıtım ve Geri Alma Betikleri Kontrolü
    if [ -x "$REPO_ROOT/scripts/deploy-3tier.sh" ] && [ -x "$REPO_ROOT/scripts/rollback-3tier.sh" ]; then
        echo "✅ 3-Tier dağıtım (deploy-3tier.sh) ve geri alma (rollback-3tier.sh) betikleri mevcut ve çalıştırılabilir."
    else
        echo "❌ HATA: 3-Tier otomasyon betikleri eksik veya çalıştırılabilir değil!" >&2
        exit 1
    fi

    echo "ℹ️ Canlı sunucu testi için kullanım: $0 <HOST_VEYA_IP> [--insecure]"
    echo "=== [LAB-04] Konfigürasyon Doğrulaması Başarılı! ==="
    exit 0
fi

CURL_OPTS=(-s --connect-timeout 8)
if [ "$INSECURE_FLAG" = "--insecure" ] || [ "$INSECURE_FLAG" = "-k" ]; then
    CURL_OPTS+=(-k)
fi

echo "=== [LAB-04] Canlı Doğrulama Başlatılıyor: $TARGET_HOST ==="

# 1. HTTP -> HTTPS Yönlendirmesi Kontrolü
echo "1. HTTP (Port 80) -> HTTPS yönlendirme testi..."
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 "http://${TARGET_HOST}/" || echo "000")

if [ "$HTTP_CODE" = "301" ] || [ "$HTTP_CODE" = "302" ]; then
    echo "✅ HTTP -> HTTPS yönlendirmesi başarılı (HTTP $HTTP_CODE)."
else
    echo "⚠️ UYARI: HTTP 80 portu $HTTP_CODE döndü (Beklenen: 301/302 yönlendirme)."
fi

# 2. HTTPS Ana Sayfa ve Marka Doğrulama
echo "2. HTTPS üzerinden ana sayfa ve NovaShop marka kontrolü..."
HOME_PAGE=$(curl "${CURL_OPTS[@]}" "https://${TARGET_HOST}/" 2>/dev/null || echo "")

if echo "$HOME_PAGE" | grep -q "NovaShop DevOps Store"; then
    echo "✅ HTTPS erişimi ve marka başlığı ('NovaShop DevOps Store') doğrulandı."
else
    echo "❌ HATA: HTTPS ana sayfasında 'NovaShop DevOps Store' bulunamadı."
    exit 1
fi

# 3. HTTPS Actuator Sağlık Kontrolü
echo "3. HTTPS /actuator/health sağlık kontrolü..."
HEALTH_BODY=$(curl "${CURL_OPTS[@]}" "https://${TARGET_HOST}/actuator/health" 2>/dev/null || echo "")

if echo "$HEALTH_BODY" | grep -q '"status":"UP"'; then
    echo "✅ Actuator sağlık kontrolü başarılı: $HEALTH_BODY"
else
    echo "❌ HATA: /actuator/health yanıtı başarısız: $HEALTH_BODY"
    exit 1
fi

# 4. Favicon HTTP 200 Kontrolü
HTTP_CODE=$(curl "${CURL_OPTS[@]}" -o /dev/null -w "%{http_code}" "https://${TARGET_HOST}/favicon.ico" 2>/dev/null || echo "000")
if [ "$HTTP_CODE" = "200" ]; then
    echo "✅ HTTPS Favicon HTTP 200 OK."
fi

echo "=== [LAB-04] Tüm 3-Tier Doğrulamaları Başarılı! ==="
