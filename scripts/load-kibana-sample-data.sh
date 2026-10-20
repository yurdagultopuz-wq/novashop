#!/usr/bin/env bash
# ==============================================================================
# NovaShop — Kibana Hazır Örnek Veri (Sample Data) Yükleme Betiği
# Kapsam: eCommerce Sipariş Logları & Web Server Erişim Logları
# ==============================================================================

set -euo pipefail

KIBANA_URL="${1:-http://localhost:5601}"
echo "==> Kibana Hazır Örnek Veri Setleri Yükleniyor: $KIBANA_URL"

load_sample() {
    local dataset="$1"
    local desc="$2"
    echo "==> Yükleniyor: $desc ($dataset)..."
    local response
    response=$(curl -s -X POST -H "kbn-xsrf: true" "$KIBANA_URL/api/sample_data/$dataset")
    echo "    Yanıt: $response"
}

# 1. E-Ticaret Sipariş Veri Seti (Grafikler, Gelir Panosu, Müşteri Siparişleri)
load_sample "ecommerce" "Kibana Sample eCommerce Data"

# 2. Web Sunucusu Erişim Günlükleri (HTTP 200/404/500, Coğrafi Harita, Trafik)
load_sample "logs" "Kibana Sample Web Access Logs"

echo "=============================================================================="
echo "✅ Hazır örnek veri setleri ve panolar başarıyla yüklendi!"
echo "   Kibana Dashboards sekmesinden [eCommerce] Revenue Dashboard ve"
echo "   [Logs] Web Traffic Dashboard panolarını doğrudan inceleyebilirsiniz."
echo "=============================================================================="
