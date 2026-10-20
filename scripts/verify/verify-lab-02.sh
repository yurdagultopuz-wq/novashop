#!/usr/bin/env bash
# NovaShop — LAB-02 AWS Temel Altyapı ve Nginx Doğrulama Betiği
set -e

EC2_HOST="${1:-}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

if [ -z "$EC2_HOST" ] || [ "$EC2_HOST" = "--config-only" ]; then
    echo "=== [LAB-02] Statik / Konfigürasyon Doğrulaması ==="
    
    # 1. Dokümantasyon ve Mimari Kılavuzu Varlık Kontrolü
    LAB02_DOC="$REPO_ROOT/labs/LAB-02/README.md"
    if [ ! -f "$LAB02_DOC" ]; then
        echo "❌ HATA: LAB-02 kılavuzu bulunamadı ($LAB02_DOC)!" >&2
        exit 1
    fi
    echo "✅ LAB-02 mimari ve uygulama kılavuzu mevcut ($LAB02_DOC)."

    # 2. VPC CIDR ve RDS Single-AZ Güvenlik Doğrulaması
    if grep -q "10.0.0.0/16" "$LAB02_DOC" && \
       grep -q "PubliclyAccessible: false" "$LAB02_DOC"; then
        echo "✅ VPC CIDR (10.0.0.0/16) ve izole RDS (PubliclyAccessible: false) yönergeleri doğrulandı."
    else
        echo "❌ HATA: LAB-02 mimari güvenlik gereksinimleri eksik!" >&2
        exit 1
    fi

    echo "ℹ️ Canlı sunucu testi için kullanım: $0 <EC2_PUBLIC_IP>"
    echo "=== [LAB-02] Konfigürasyon Doğrulaması Başarılı! ==="
    exit 0
fi

echo "=== [LAB-02] Canlı AWS Doğrulaması Başlatılıyor: $EC2_HOST ==="

# 1. HTTP 80 Ana Sayfa Yanıtı (Beklenen: 200 OK)
echo "1. Ana sayfa (HTTP 200) kontrol ediliyor..."
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 "http://${EC2_HOST}/" || echo "000")

if [ "$HTTP_CODE" = "200" ]; then
    echo "✅ Ana sayfa HTTP 200 OK döndü."
else
    echo "❌ HATA: Ana sayfa $HTTP_CODE döndü (Beklenen: 200)."
    exit 1
fi

# 2. Sağlık Kontrolü Endpoint'i (/healthz)
echo "2. Sağlık kontrolü (/healthz) test ediliyor..."
HEALTH_BODY=$(curl -s --connect-timeout 5 "http://${EC2_HOST}/healthz" || true)

if echo "$HEALTH_BODY" | grep -q '"status":"UP"'; then
    echo "✅ Sağlık kontrolü başarılı: $HEALTH_BODY"
else
    echo "❌ HATA: /healthz beklenen yanıtı vermedi: $HEALTH_BODY"
    exit 1
fi

echo "=== [LAB-02] Tüm Testler Başarılı! ==="
