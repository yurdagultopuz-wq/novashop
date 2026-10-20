#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

if [ -f ".env" ]; then
    set -a
    # shellcheck disable=SC1091
    source ".env"
    set +a
else
    echo "⚠️ UYARI: .env dosyası bulunamadı. Lütfen 'cp .env.example .env' komutu ile oluşturup düzenleyin." >&2
fi

echo "=== NovaShop 3-Tier Dağıtımı Başlatılıyor ==="
docker compose -f docker-compose.prod.yml up -d

echo "=== Konteynerlerin Sağlık Durumu Kontrol Ediliyor ==="
sleep 5
docker compose -f docker-compose.prod.yml ps
