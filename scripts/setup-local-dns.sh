#!/usr/bin/env bash
# ==============================================================================
# NovaShop — Yerel DNS Çözümleme Betiği (/etc/hosts)
# ==============================================================================
# Cloudflare DNS yayılımı beklenmeden veya harici bağlantı gerekmeksizin
# tüm servis alt alan adlarının yerel makinede doğrudan çalışmasını sağlar.
#
# Kullanım:
#   sudo bash scripts/setup-local-dns.sh [SUNUCU_IP] [STUDENT_ID]
#   Örnek: sudo bash scripts/setup-local-dns.sh 127.0.0.1 student01
# ==============================================================================
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
   echo "❌ Bu betik /etc/hosts dosyasını güncellemek için 'sudo' ile çalıştırılmalıdır."
   echo "Örnek: sudo bash scripts/setup-local-dns.sh 127.0.0.1 student01"
   exit 1
fi

SERVER_IP="${1:-127.0.0.1}"
STUDENT_ID="${2:-${STUDENT_ID:-student01}}"
DOMAIN="${DOMAIN_NAME:-devopsatolyesi.com}"

SERVICES=(
  cockpit
  novashop
  kind
  gitlab
  harbor
  sonarqube
  jenkins
  prometheus
  grafana
  jaeger
  kibana
  elastic
  argocd
)

ENTRIES=""
for svc in "${SERVICES[@]}"; do
  ENTRIES="${ENTRIES} ${STUDENT_ID}-${svc}.${DOMAIN}"
done

echo "===> [${STUDENT_ID}] için alan adları ${SERVER_IP} adresine bağlanıyor..."

# Varsa eski student kayıtlarını temizle
if [[ "$OSTYPE" == "darwin"* ]]; then
    sed -i '' "/${STUDENT_ID}-.*\\.${DOMAIN}/d" /etc/hosts 2>/dev/null || true
else
    sed -i "/${STUDENT_ID}-.*\\.${DOMAIN}/d" /etc/hosts 2>/dev/null || true
fi

# Yeni satırı ekle
echo "${SERVER_IP} ${ENTRIES}" >> /etc/hosts

echo "======================================================================"
echo "✅ /etc/hosts başarıyla güncellendi!"
echo "======================================================================"
echo "Artık tarayıcınızdan doğrudan erişebilirsiniz:"
echo "🔗 Kibana       : https://${STUDENT_ID}-kibana.${DOMAIN}"
echo "🔗 Elasticsearch: https://${STUDENT_ID}-elastic.${DOMAIN}"
echo "🔗 Jaeger       : https://${STUDENT_ID}-jaeger.${DOMAIN}"
echo "🔗 Argo CD      : https://${STUDENT_ID}-argocd.${DOMAIN}"
echo "🔗 Prometheus   : https://${STUDENT_ID}-prometheus.${DOMAIN}"
echo "🔗 Grafana      : https://${STUDENT_ID}-grafana.${DOMAIN}"
echo "======================================================================"
