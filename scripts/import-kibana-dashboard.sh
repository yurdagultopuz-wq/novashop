#!/usr/bin/env bash
# ==============================================================================
# NovaShop — Kibana Dashboard ve Görselleştirme Otomatik İçe Aktarma Betiği
# Kapsam: Saved Objects API ile Hatasız, Eksiksiz Merkezi Log Panosu Yükleme
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DASHBOARD_FILE="$REPO_ROOT/deploy/logging/kibana/novashop-central-logging-dashboard.json"

KIBANA_URL="${1:-http://localhost:5601}"
echo "==> Kibana Merkezi Loglama Dashboard içe aktarılıyor: $KIBANA_URL"

if [ ! -f "$DASHBOARD_FILE" ]; then
    echo "❌ Hata: Dashboard şablon dosyası bulunamadı: $DASHBOARD_FILE"
    exit 1
fi

# Kibana hazır olana kadar bekle
until curl -s -f -H 'kbn-xsrf: true' "$KIBANA_URL/api/status" > /dev/null; do
    echo "    Kibana API bekleniyor ($KIBANA_URL)..."
    sleep 3
done

# Dashboard Nesnesini Dosyadan Yükle / Güncelle
echo "==> 'NovaShop — Merkezi Log ve Sistem Analiz Panosu' kaydediliyor..."
RESPONSE=$(curl -s -X POST \
  -H "kbn-xsrf: true" \
  -H "Content-Type: application/json" \
  "$KIBANA_URL/api/saved_objects/dashboard/novashop-central-logging?overwrite=true" \
  --data-binary @"$DASHBOARD_FILE")

echo "✅ Dashboard başarıyla oluşturuldu: $(echo "$RESPONSE" | grep -o '"title":"[^"]*"' || echo "OK")"
echo "=============================================================================="
echo "🔗 Kibana Panosuna Doğrudan Erişim Linki:"
echo "   http://localhost:5601/app/dashboards#/view/novashop-central-logging"
echo "=============================================================================="
