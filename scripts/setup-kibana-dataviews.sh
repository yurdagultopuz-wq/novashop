#!/usr/bin/env bash
# ==============================================================================
# NovaShop — Kibana Data Views (Index Patterns) Otomatik Yapılandırma Betiği
# Kapsam: novashop-*, novashop-docker-*, novashop-k8s-*, novashop-ubuntu-*
# ==============================================================================

set -euo pipefail

KIBANA_URL="${1:-http://localhost:5601}"
echo "==> Kibana Data Views yapılandırması başlatılıyor: $KIBANA_URL"

# Kibana hazır olana kadar bekle
until curl -s -f -H 'kbn-xsrf: true' "$KIBANA_URL/api/status" > /dev/null; do
    echo "    Kibana bekleniyor ($KIBANA_URL)..."
    sleep 3
done
echo "✅ Kibana API hazır."

create_dataview() {
    local title="$1"
    local name="$2"
    local time_field="${3:-@timestamp}"
    local id="${4:-}"

    echo "==> Data View oluşturuluyor: $name ($title)..."
    local json_payload
    if [ -n "$id" ]; then
        json_payload="{
            \"data_view\": {
                \"id\": \"$id\",
                \"title\": \"$title\",
                \"name\": \"$name\",
                \"timeFieldName\": \"$time_field\"
            }
        }"
    else
        json_payload="{
            \"data_view\": {
                \"title\": \"$title\",
                \"name\": \"$name\",
                \"timeFieldName\": \"$time_field\"
            }
        }"
    fi

    local status_code
    status_code=$(curl -s -o /dev/null -w "%{http_code}" -X POST \
        -H "kbn-xsrf: true" \
        -H "Content-Type: application/json" \
        "$KIBANA_URL/api/data_views/data_view" \
        -d "$json_payload")

    if [ "$status_code" -eq 200 ] || [ "$status_code" -eq 409 ]; then
        echo "    ✅ $name hazır (HTTP $status_code)."
    else
        echo "    ⚠️ $name oluşturulurken beklenmeyen yanıt: HTTP $status_code"
    fi
}

# 1. Tüm NovaShop Logları (Docker + K8s + Ubuntu)
create_dataview "novashop-*" "NovaShop — Tüm Sistem Logları (K8s, Docker, Ubuntu)" "@timestamp" "novashop-all"

# 2. Docker Konteyner Logları (Uygulamalar, Jenkins, GitLab vb.)
create_dataview "novashop-docker-*" "NovaShop — Docker Konteyner Logları" "@timestamp" "novashop-docker"

# 3. Kubernetes Pod Logları
create_dataview "novashop-k8s-*" "NovaShop — Kubernetes (Kind) Pod Logları" "@timestamp" "novashop-k8s"

# 4. Ubuntu Host Sistem Logları
create_dataview "novashop-ubuntu-*" "NovaShop — Ubuntu Sunucu Syslog & Auth" "@timestamp" "novashop-ubuntu"

# 5. Jenkins CI/CD Logları
create_dataview "novashop-jenkins-*" "NovaShop — Jenkins CI/CD Boru Hattı Logları" "@timestamp" "novashop-jenkins"

echo "=============================================================================="
echo "✅ Tüm Kibana Data Views başarıyla yapılandırıldı!"
echo "   Kibana Discover ekranından dilediğiniz veri görünümünü seçebilirsiniz."
echo "=============================================================================="
