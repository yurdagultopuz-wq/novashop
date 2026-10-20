#!/usr/bin/env bash
# ==============================================================================
# NovaShop — LAB-09 Argo CD GitOps Otomatik Kurulum ve Temizlik Betiği
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# 0. Kubernetes Küme Varlık Kontrolü
if ! kubectl get nodes >/dev/null 2>&1; then
    echo "⚠️ Kubernetes kümesi bulunamadı. Kind kümesi başlatılıyor..."
    bash "$SCRIPT_DIR/setup-kind-cluster.sh"
fi

echo "===> [1/4] Argo CD Namespace ve Manifestoları Kuruluyor..."
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl apply --server-side --force-conflicts -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

echo "===> [2/4] Argo CD Sunucusunun Hazır Olması Bekleniyor..."
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd

echo "===> [3/4] Olası NodePort 30080 Çakışmaları Otomatik Temizleniyor..."
# Manuel Helm kurulumundan kalan çakışan servisi temizle:
helm uninstall novashop -n novashop 2>/dev/null || true
kubectl delete svc novashop-ui -n novashop --ignore-not-found 2>/dev/null || true

echo "===> [4/4] Argo CD GitOps Application Uygulanıyor..."
kubectl apply -f "$REPO_ROOT/deploy/gitops/application.yaml"

# Cockpit Nginx ve Yerel Erişim için Port Yönlendirme (Port 18082)
pkill -f "port-forward svc/argocd-server" 2>/dev/null || true
nohup kubectl port-forward svc/argocd-server -n argocd 18082:443 --address 0.0.0.0 > /dev/null 2>&1 &

echo ""
echo "======================================================================"
echo "🎉 Argo CD GitOps Başarıyla Kuruldu!"
echo "======================================================================"
ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" 2>/dev/null | base64 -d || echo "")
echo "Web UI Adresi: https://localhost:18082 (veya ters vekil alan adınız)"
echo "Kullanıcı Adı: admin"
echo "Admin Parola : ${ARGOCD_PASSWORD}"
echo "======================================================================"
