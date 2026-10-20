#!/usr/bin/env bash
# NovaShop — LAB-07 Kurumsal CI/CD (GitLab, Jenkins, Harbor) Doğrulama Betiği
set -e

HARBOR_HOST="${1:-}"

echo "=== [LAB-07] Kurumsal CI/CD ve Harbor Doğrulama Başlatılıyor ==="

# 1. Pipeline Tanım Dosyaları Kontrolü
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

FOUND_PIPELINE=false
if [ -f "$REPO_ROOT/Jenkinsfile" ]; then
    echo "✅ Jenkinsfile bildirimsel pipeline tanımı mevcut."
    FOUND_PIPELINE=true
fi

if [ -f "$REPO_ROOT/.gitlab-ci.yml" ]; then
    echo "✅ .gitlab-ci.yml GitLab CI pipeline tanımı mevcut."
    FOUND_PIPELINE=true
fi

if [ -d "$REPO_ROOT/.github/workflows" ]; then
    echo "✅ GitHub Actions iş akışları mevcut."
    FOUND_PIPELINE=true
fi

if [ "$FOUND_PIPELINE" = false ]; then
    echo "ℹ️ Bilgi: Kök dizinde Jenkinsfile veya .gitlab-ci.yml henüz oluşturulmamış."
fi

# 2. Canlı Harbor Registry Kontrolü (Verilmişse veya Yerel 18082)
HARBOR_TARGET="${HARBOR_HOST:-127.0.0.1:18082}"
if [[ "$HARBOR_TARGET" =~ ^https?:// ]]; then
    HARBOR_BASE="$HARBOR_TARGET"
elif [[ "$HARBOR_TARGET" =~ \.[a-zA-Z]{2,} ]]; then
    HARBOR_BASE="https://${HARBOR_TARGET}"
else
    HARBOR_BASE="http://${HARBOR_TARGET}"
fi

echo "2. Harbor canlı servis kontrolü yapılıyor: $HARBOR_BASE"
PING_RESP=$(curl -sSL -k --connect-timeout 5 "${HARBOR_BASE}/api/v2.0/ping" 2>/dev/null || echo "")
if echo "$PING_RESP" | grep -qi "pong"; then
    echo "✅ Harbor API ping başarılı (pong)."
else
    echo "⚠️ UYARI: Harbor API /api/v2.0/ping yanıt vermedi ($HARBOR_BASE). Port/IP kontrol edin."
fi

HEALTH_RESP=$(curl -sSL -k --connect-timeout 5 "${HARBOR_BASE}/api/v2.0/health" 2>/dev/null || echo "")
if echo "$HEALTH_RESP" | grep -q '"status":"healthy"'; then
    echo "✅ Harbor genel sağlık durumu: healthy."
fi

echo "=== [LAB-07] Kurumsal CI/CD Doğrulama Tamamlandı ==="
