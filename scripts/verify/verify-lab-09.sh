#!/usr/bin/env bash
# NovaShop — LAB-09 ArgoCD GitOps Doğrulama Betiği
set -e

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

echo "=== [LAB-09] ArgoCD GitOps Doğrulama Başlatılıyor ==="

# 1. ArgoCD Application Manifest Taraması
APP_MANIFEST=$(find "$REPO_ROOT" -name "*argocd*app*.yaml" -o -name "*application*.yaml" 2>/dev/null | head -n 1 || echo "")

if [ -n "$APP_MANIFEST" ] && [ -f "$APP_MANIFEST" ]; then
    echo "✅ ArgoCD Application manifesti bulundu: $APP_MANIFEST"

    # Self-healing kontrolü
    if grep -q "selfHeal: true" "$APP_MANIFEST"; then
        echo "✅ Otomatik drift düzeltme (selfHeal: true) aktif."
    else
        echo "⚠️ UYARI: syncPolicy altında selfHeal: true tanımlanmamış."
    fi

    # Prune kontrolü
    if grep -q "prune: true" "$APP_MANIFEST"; then
        echo "✅ Yetim kaynak temizleme (prune: true) aktif."
    fi

    # Namespace kontrolü
    if grep -q "namespace: novashop" "$APP_MANIFEST"; then
        echo "✅ Hedef kubernetes namespace: novashop."
    fi
else
    echo "ℹ️ Bilgi: Projede yerel ArgoCD Application CRD manifesti aranıyor..."
    echo "   (deploy/gitops/ dizini altında manifest beklenmektedir)"
fi

# 2. Canlı ArgoCD CLI / Sunucu Kontrolü (Varsa)
ARGOCD_SERVER="${1:-}"
if [ -n "$ARGOCD_SERVER" ]; then
    echo "2. ArgoCD sunucu erişim testi: $ARGOCD_SERVER"
    HTTP_CODE=$(curl -s -k -o /dev/null -w "%{http_code}" "https://${ARGOCD_SERVER}/" 2>/dev/null || echo "000")
    if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "307" ] || [ "$HTTP_CODE" = "308" ]; then
        echo "✅ ArgoCD Web UI erişilebilir (HTTP $HTTP_CODE)."
    fi
fi

echo "=== [LAB-09] ArgoCD GitOps Doğrulama Tamamlandı ==="
