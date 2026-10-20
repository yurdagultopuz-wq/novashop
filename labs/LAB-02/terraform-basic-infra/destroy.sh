#!/usr/bin/env bash
# ==============================================================================
# NovaShop LAB-02: Kaynakları Tek Komutla İmha Etme (Cleanup)
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "======================================================================"
echo "⚠️ NovaShop LAB-02 Terraform Kaynakları Siliniyor (destroy)..."
echo "======================================================================"

# 1. AWS Kimlik Doğrulaması Kontrolü
if ! aws sts get-caller-identity >/dev/null 2>&1; then
    echo "❌ HATA: AWS kimlik doğrulaması başarısız!"
    echo "Lütfen AWS kimlik bilgilerinizi tanımlayın (aws configure veya ortam değişkenleri)."
    exit 1
fi

AWS_REGION="${AWS_DEFAULT_REGION:-${AWS_REGION:-$(aws configure get region 2>/dev/null || true)}}"
AWS_REGION="${AWS_REGION:-us-east-1}"
export AWS_DEFAULT_REGION="$AWS_REGION"
export AWS_REGION="$AWS_REGION"

terraform destroy -auto-approve -var="aws_region=$AWS_DEFAULT_REGION"

echo "✅ Tüm AWS kaynakları (VPC, EC2, RDS) başarıyla temizlendi."
