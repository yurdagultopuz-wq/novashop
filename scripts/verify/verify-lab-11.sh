#!/usr/bin/env bash
# NovaShop — LAB-11 Merkezi Günlükleme (Fluent Bit, Elasticsearch, Kibana) Doğrulama Betiği
set -e

ES_HOST="${1:-localhost:9200}"

echo "=== [LAB-11] Merkezi Günlükleme Doğrulama Başlatılıyor ==="

# 1. Konteyner Loglarında Trace-ID Format Denetimi
echo "1. Uygulama loglarında Trace-ID / Span-ID korelasyon kontrolü..."
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

if grep -rn "traceId" "$REPO_ROOT/src/ui" 2>/dev/null || grep -rn "trace_id" "$REPO_ROOT/src" 2>/dev/null; then
    echo "✅ Kaynak kodda dağıtık log korelasyonu (traceId / spanId) kalıbı mevcut."
fi

# 2. Elasticsearch Canlı Sağlık Kontrolü (Opsiyonel)
echo "2. Elasticsearch canlı cluster durumu test ediliyor ($ES_HOST)..."
ES_HEALTH=$(curl -s --connect-timeout 3 "http://${ES_HOST}/_cluster/health" 2>/dev/null || echo "")

if echo "$ES_HEALTH" | grep -qE '"status":"(green|yellow)"'; then
    echo "✅ Elasticsearch cluster sağlıklı ($ES_HEALTH)."
    K8S_INDICES=$(curl -s "http://${ES_HOST}/_cat/indices/novashop-k8s*?h=index,docs.count" 2>/dev/null || echo "")
    if [ -n "$K8S_INDICES" ]; then
        echo "✅ Kubernetes (Kind) pod log indeksi aktif:"
        echo "$K8S_INDICES"
    fi
else
    echo "ℹ️ Bilgi: Elasticsearch ($ES_HOST) erişilemedi veya henüz başlatılmadı."
fi

echo "=== [LAB-11] Merkezi Günlükleme Doğrulama Tamamlandı ==="
