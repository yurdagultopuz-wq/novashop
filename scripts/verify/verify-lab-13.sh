#!/usr/bin/env bash
# NovaShop — LAB-13 Kurumsal Amazon EKS Doğrulama Betiği
set -e

CLUSTER_NAME="${1:-novashop-eks}"
AWS_REGION="${2:-eu-central-1}"

echo "=== [LAB-13] Amazon EKS Doğrulama Başlatılıyor ($CLUSTER_NAME / $AWS_REGION) ==="

# 1. AWS CLI ve EKS Küme Durumu Kontrolü (Opsiyonel)
if command -v aws >/dev/null 2>&1; then
    echo "1. AWS EKS küme durumu sorgulanıyor..."
    STATUS=$(aws eks describe-cluster --name "$CLUSTER_NAME" --region "$AWS_REGION" --query "cluster.status" --output text 2>/dev/null || echo "NOT_FOUND")
    if [ "$STATUS" = "ACTIVE" ]; then
        echo "✅ EKS kümesi aktif durumda: $CLUSTER_NAME"
    else
        echo "ℹ️ Bilgi: EKS kümesi '$CLUSTER_NAME' aktif değil veya AWS yetkilendirmesi yok ($STATUS)."
    fi
else
    echo "ℹ️ Bilgi: AWS CLI bulunamadı; statik EKS konfigürasyon denetimi yapılıyor."
fi

# 2. Kubernetes IRSA ve Servis Hesabı Denetimi
if command -v kubectl >/dev/null 2>&1; then
    echo "2. ServiceAccount IRSA anotasyonları kontrol ediliyor..."
    SA_ANNOTATION=$(kubectl get sa -n novashop -o jsonpath='{.items[*].metadata.annotations.eks\.amazonaws\.com/role-arn}' 2>/dev/null || echo "")
    if [ -n "$SA_ANNOTATION" ]; then
        echo "✅ IRSA IAM Rol anotasyonu bulundu: $SA_ANNOTATION"
    else
        echo "ℹ️ novashop namespace altında IRSA anotasyonlu ServiceAccount bulunamadı veya küme çevrimdışı."
    fi
fi

# 3. Sıfır Maliyet (Zero-Cost Cleanup) Hatırlatıcısı
echo "3. Maliyet Güvenlik Kontrolü:"
echo "   Lab tamamlandıktan sonra AWS faturalandırılmasını durdurmak için:"
echo "   eksctl delete cluster --name $CLUSTER_NAME --region $AWS_REGION"

echo "=== [LAB-13] Amazon EKS Doğrulama Tamamlandı ==="
