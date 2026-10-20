#!/usr/bin/env bash
# NovaShop — LAB-06 Kubernetes ve Helm Doğrulama Betiği
set -e

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CHART_DIR="${REPO_ROOT}/charts/novashop"

echo "=== [LAB-06] Kubernetes ve Helm Doğrulama Başlatılıyor ==="

# 1. Helm Chart Dizin ve Dosya Varlığı
if [ ! -d "$CHART_DIR" ]; then
    echo "❌ HATA: Helm chart dizini bulunamadı ($CHART_DIR)."
    exit 1
fi
echo "✅ Helm chart dizini mevcut: $CHART_DIR"

REQUIRED_FILES=("Chart.yaml" "values.yaml" "templates/_helpers.tpl" "templates/ui-deployment.yaml" "templates/ui-service.yaml")
for f in "${REQUIRED_FILES[@]}"; do
    if [ ! -f "$CHART_DIR/$f" ]; then
        echo "❌ HATA: Gerekli Helm dosyası eksik: $f"
        exit 1
    fi
done
echo "✅ Tüm temel Helm chart şablonları mevcut."

# 2. Chart values.yaml Güvenlik ve Kaynak Sınırları Kontrolü
VALUES_FILE="$CHART_DIR/values.yaml"

# Probes kontrolü
if grep -q "livenessProbe" "$VALUES_FILE" && grep -q "readinessProbe" "$VALUES_FILE"; then
    echo "✅ Liveness ve Readiness sağlık probları tanımlı."
else
    echo "❌ HATA: values.yaml içinde livenessProbe veya readinessProbe eksik."
    exit 1
fi

# Kaynak sınırları (PROFILES.md koruması)
if grep -q "limits:" "$VALUES_FILE" && grep -q "memory:" "$VALUES_FILE"; then
    echo "✅ Kaynak sınırları (resources.limits) tanımlı."
else
    echo "⚠️ UYARI: values.yaml içinde CPU/Bellek limitleri eksik olabilir."
fi

# Güvenlik context'i
if grep -q "runAsNonRoot: true" "$VALUES_FILE"; then
    echo "✅ Non-root kullanıcı güvenlik kuralı (runAsNonRoot: true) tanımlı."
fi

# 3. Canlı Küme / Helm CLI Kontrolü (Opsiyonel)
if command -v helm >/dev/null 2>&1; then
    echo "3. Helm lint doğrulaması çalıştırılıyor..."
    helm lint "$CHART_DIR"
    echo "✅ Helm lint başarıyla tamamlandı."
else
    echo "ℹ️ Bilgi: Helm CLI yüklü değil; statik şablon doğrulaması yapıldı."
fi

if command -v kubectl >/dev/null 2>&1; then
    if kubectl cluster-info >/dev/null 2>&1; then
        echo "✅ Kubernetes kümesine erişim sağlandı."
        kubectl get pods -n novashop 2>/dev/null || echo "ℹ️ novashop namespace henüz oluşturulmamış."
    fi
fi

echo "=== [LAB-06] Kubernetes ve Helm Doğrulaması Tamamlandı! ==="
