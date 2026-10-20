#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# .env varsa ortam değişkenlerini yükle
if [ -f "$SCRIPT_DIR/.env" ]; then
    set -a
    # shellcheck disable=SC1091
    source "$SCRIPT_DIR/.env"
    set +a
fi

TARGET_CN="${DOMAIN:-${EC2_PUBLIC_IP:-localhost}}"

echo "=== 1. TLS Sertifikası Üretiliyor (CN: ${TARGET_CN}) ==="
sudo mkdir -p /etc/ssl/novashop
sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /etc/ssl/novashop/novashop.key \
  -out /etc/ssl/novashop/novashop.crt \
  -subj "/C=TR/ST=Istanbul/L=DevOps/O=NovaShop/CN=${TARGET_CN}"

sudo chmod 600 /etc/ssl/novashop/novashop.key
sudo chmod 644 /etc/ssl/novashop/novashop.crt

echo "=== 2. Nginx Konfigürasyonu Kopyalanıyor ==="
sudo cp "$SCRIPT_DIR/novashop-3tier.conf" /etc/nginx/conf.d/novashop-3tier.conf
sudo rm -f /etc/nginx/conf.d/novashop.conf /etc/nginx/sites-enabled/default 2>/dev/null || true

echo "=== 3. Nginx Test ve Yeniden Başlatma ==="
sudo nginx -t
sudo systemctl restart nginx
echo "✅ Nginx TLS ve ters vekil başarıyla yapılandırıldı."
