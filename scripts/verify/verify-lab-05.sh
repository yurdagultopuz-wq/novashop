#!/usr/bin/env bash
# NovaShop — LAB-05 GitHub Actions CI/CD Doğrulama Betiği
set -e

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WORKFLOWS_DIR="${REPO_ROOT}/.github/workflows"

echo "=== [LAB-05] GitHub Actions Doğrulama Başlatılıyor ==="

# 1. Workflows Dizini Kontrolü
if [ ! -d "$WORKFLOWS_DIR" ]; then
    echo "❌ HATA: .github/workflows dizini bulunamadı ($WORKFLOWS_DIR)."
    exit 1
fi
echo "✅ Workflows dizini mevcut."

# 2. Workflow Dosyası Varlığı
WORKFLOW_COUNT=$(find "$WORKFLOWS_DIR" -type f \( -name "*.yml" -o -name "*.yaml" \) | wc -l | tr -d ' ')
if [ "$WORKFLOW_COUNT" -eq 0 ]; then
    echo "❌ HATA: .github/workflows içinde en az bir YAML iş akışı bulunmalıdır."
    exit 1
fi
echo "✅ Bulunan iş akışı sayısı: $WORKFLOW_COUNT"

# 3. Güvenlik Denetimi: OIDC ve Sert Kimlik Doğrulama
HAS_OIDC=false
for wf in "$WORKFLOWS_DIR"/*.yml "$WORKFLOWS_DIR"/*.yaml; do
    [ -f "$wf" ] || continue
    if grep -q "id-token: write" "$wf" || grep -q "aws-actions/configure-aws-credentials" "$wf"; then
        HAS_OIDC=true
        echo "✅ OIDC / AWS kimlik sağlayıcı tanımı tespit edildi: $(basename "$wf")"
    fi
done

if [ "$HAS_OIDC" = false ]; then
    echo "⚠️ UYARI: İş akışlarında 'id-token: write' veya 'configure-aws-credentials' bulunamadı."
fi

# 4. Anti-Pattern Denetimi: Hardcoded AWS Anahtarı Taraması
LEAK_COUNT=0
for wf in "$WORKFLOWS_DIR"/*.yml "$WORKFLOWS_DIR"/*.yaml; do
    [ -f "$wf" ] || continue
    if grep -E "AKIA[0-9A-Z]{16}" "$wf"; then
        echo "❌ HATA: $(basename "$wf") içinde hardcoded AWS Access Key bulundu!"
        LEAK_COUNT=$((LEAK_COUNT + 1))
    fi
done

if [ "$LEAK_COUNT" -gt 0 ]; then
    echo "❌ Güvenlik kontrolü başarısız: İş akışlarında düz metin gizli anahtar bulundu."
    exit 1
fi
echo "✅ Hardcoded AWS gizli anahtarı bulunmadı (Güvenli)."

# 5. Anti-Pattern Denetimi: :latest Tag Yasağı
LATEST_TAG_COUNT=0
for wf in "$WORKFLOWS_DIR"/*.yml "$WORKFLOWS_DIR"/*.yaml; do
    [ -f "$wf" ] || continue
    if grep -E "novashop-.*:latest" "$wf"; then
        echo "⚠️ UYARI: $(basename "$wf") içinde ':latest' etiketli push işlemi tespit edildi."
        LATEST_TAG_COUNT=$((LATEST_TAG_COUNT + 1))
    fi
done

if [ "$LATEST_TAG_COUNT" -eq 0 ]; then
    echo "✅ İmaj etiketleme kuralları temiz (SHA veya semantik versiyon kullanılıyor)."
fi

echo "=== [LAB-05] GitHub Actions Doğrulaması Tamamlandı! ==="
