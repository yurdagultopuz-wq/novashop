#!/usr/bin/env bash
# NovaShop — Kind Küme Kurulum ve Helm Dağıtım Otomasyonu
set -euo pipefail

CLUSTER_NAME="novashop-cluster"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CONFIG_FILE="$REPO_ROOT/deploy/k8s/kind-cluster-config.yaml"

echo "=== [NovaShop] Kind Kubernetes Kümesi Kurulumu Başlatılıyor ==="

# 1. Gerekli Araçların Varlık Kontrolü
for tool in kind kubectl helm; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        echo "❌ HATA: '$tool' komutu bulunamadı. Lütfen kurulumunu tamamlayın." >&2
        exit 1
    fi
done

# 2. Host Log Dizinlerini Hazırla (LAB-11 Fluent Bit entegrasyonu için)
mkdir -p /var/log/containers /var/log/pods 2>/dev/null || sudo mkdir -p /var/log/containers /var/log/pods 2>/dev/null || true
chmod 777 /var/log/containers /var/log/pods 2>/dev/null || sudo chmod 777 /var/log/containers /var/log/pods 2>/dev/null || true

# 3. Mevcut Küme Varsa Kontrol Et veya Yenisini Oluştur
if kind get clusters | grep -q "^${CLUSTER_NAME}$"; then
    echo "ℹ️ '${CLUSTER_NAME}' isimli küme zaten mevcut."
else
    echo "3. Çok düğümlü Kind kümesi oluşturuluyor (1 control-plane, 2 worker)..."
    kind create cluster --config "$CONFIG_FILE"
fi

# Always target this lab's cluster, even if another Kind cluster was active.
kubectl config use-context "kind-${CLUSTER_NAME}"

# 4. Kümeyi ve Düğümleri Doğrula
kubectl cluster-info --context "kind-${CLUSTER_NAME}"
echo "4. Bütün Kind düğümlerinin Ready olması bekleniyor (en fazla 5 dakika)..."
if ! kubectl wait --for=condition=Ready nodes --all --timeout=5m; then
    echo "❌ HATA: Kind düğümleri 5 dakika içinde Ready olmadı. Tanılama:" >&2
    kubectl get nodes -o wide || true
    kubectl get pods -n kube-system -o wide || true
    exit 1
fi
echo "✅ Bütün düğümler Ready. Düğüm Durumları:"
kubectl get nodes -o wide

# 5. novashop Namespace Oluşturma
if ! kubectl get namespace novashop >/dev/null 2>&1; then
    echo "5. 'novashop' namespace oluşturuluyor..."
    kubectl create namespace novashop
fi

# 6. İmaj Hazırlığı: Yerel novashop-ui:v0.1.0 varsa yükle, yoksa public imaj kullan
HELM_EXTRA_ARGS=""
if docker image inspect novashop-ui:v0.1.0 >/dev/null 2>&1; then
    echo "ℹ️ Yerel 'novashop-ui:v0.1.0' imajı tespit edildi, Kind kümesine aktarılıyor..."
    kind load docker-image novashop-ui:v0.1.0 --name "${CLUSTER_NAME}" || true
    HELM_EXTRA_ARGS="--set ui.image.repository=novashop-ui --set ui.image.tag=v0.1.0"
else
    echo "ℹ️ Yerel imaj bulunamadı; genel erişilebilir 'public.ecr.aws/aws-containers/retail-store-sample-ui:1.6.2' kullanılıyor."
fi

# 7. Helm Chart ile NovaShop Uygulamasını Dağıtma
echo "7. NovaShop Helm chart dağıtılıyor..."
helm upgrade --install novashop "$REPO_ROOT/charts/novashop" \
  --namespace novashop \
  $HELM_EXTRA_ARGS \
  --wait \
  --timeout 10m

# 8. Dağıtım Durumunu Doğrulama
echo "8. Dağıtılan kaynaklar listeleniyor..."
kubectl get all -n novashop

echo "=== [NovaShop] Kind ve Helm Mikroservis Dağıtımı Başarıyla Tamamlandı! ==="
echo "1. UI Storefront (Java/Spring):   http://localhost:30080 (Metrik: /actuator/prometheus)"
echo "2. Catalog Servisi (Go/Gin):      http://localhost:30081 (Metrik: /metrics)"
echo "3. Cart Servisi (Java/Spring):    http://localhost:30082 (Metrik: /actuator/prometheus)"
echo "4. Orders Servisi (Java/Spring):  http://localhost:30083 (Metrik: /actuator/prometheus)"
echo "5. Checkout Servisi (Node.js):    http://localhost:30085 (Metrik: /metrics)"
