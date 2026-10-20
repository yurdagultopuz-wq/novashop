#!/usr/bin/env bash
# ==============================================================================
# NovaShop LAB-02: Tek Komutla AWS Altyapı Kurulumu (Zero-Touch Automation)
# ==============================================================================
# Bu script tamamen dinamiktir:
# 1. 'aws configure' veya ortam değişkenleri ile AWS bağlantısını doğrular.
# 2. AWS Hesap ID'sini ve Bölgeyi (Region) otomatik tespit eder.
# 3. Hesaba özel S3 tfstate bucket'ını kontrol eder, yoksa oluşturup versiyonlar.
# 4. 'novashop-key' SSH anahtar çiftini kontrol edip yoksa oluşturur.
# 5. terraform.tfvars yoksa şablondan oluşturur.
# 6. Terraform'u S3 backend ile başlatır (init) ve altyapıyı kurar (apply).
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "======================================================================"
echo "🚀 NovaShop LAB-02 Terraform Altyapı Dağıtımı Başlatılıyor"
echo "======================================================================"

# 1. AWS Kimlik Doğrulaması Kontrolü
echo "▶ 1. AWS Kimlik Doğrulaması kontrol ediliyor..."
if ! aws sts get-caller-identity >/dev/null 2>&1; then
    echo "❌ HATA: AWS kimlik doğrulaması başarısız!"
    echo "Lütfen AWS kimlik bilgilerinizi aşağıdaki yollardan biriyle tanımlayın:"
    echo "  1) 'aws configure' komutu ile Access Key ve Secret Key girin."
    echo "  2) Veya ortam değişkenlerini tanımlayın:"
    echo "     export AWS_ACCESS_KEY_ID=\"...\""
    echo "     export AWS_SECRET_ACCESS_KEY=\"...\""
    echo "     export AWS_DEFAULT_REGION=\"us-east-1\""
    exit 1
fi

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
IAM_ARN=$(aws sts get-caller-identity --query Arn --output text)

# Bölge tespiti (Öncelik: AWS_DEFAULT_REGION -> AWS_REGION -> aws configure region -> us-east-1)
AWS_REGION="${AWS_DEFAULT_REGION:-${AWS_REGION:-$(aws configure get region 2>/dev/null || true)}}"
AWS_REGION="${AWS_REGION:-us-east-1}"
export AWS_DEFAULT_REGION="$AWS_REGION"
export AWS_REGION="$AWS_REGION"

echo "   ✓ AWS Hesap ID  : $ACCOUNT_ID"
echo "   ✓ IAM Kimliği   : $IAM_ARN"
echo "   ✓ Bölge (Region): $AWS_DEFAULT_REGION"

# 2. S3 tfstate Bucket Yönetimi
BUCKET_NAME="${TF_STATE_BUCKET:-novashop-tfstate-${ACCOUNT_ID}}"
echo "▶ 2. S3 tfstate bucket kontrol ediliyor: $BUCKET_NAME ..."
if aws s3api head-bucket --bucket "$BUCKET_NAME" 2>/dev/null; then
    echo "   ✓ S3 bucket mevcut: $BUCKET_NAME"
else
    echo "   + S3 bucket oluşturuluyor: $BUCKET_NAME (Bölge: $AWS_DEFAULT_REGION) ..."
    if [ "$AWS_DEFAULT_REGION" = "us-east-1" ]; then
        aws s3api create-bucket --bucket "$BUCKET_NAME" --region "$AWS_DEFAULT_REGION"
    else
        aws s3api create-bucket --bucket "$BUCKET_NAME" --region "$AWS_DEFAULT_REGION" \
            --create-bucket-configuration LocationConstraint="$AWS_DEFAULT_REGION"
    fi
    aws s3api put-bucket-versioning --bucket "$BUCKET_NAME" --versioning-configuration Status=Enabled
    echo "   ✓ S3 bucket başarıyla oluşturuldu ve versiyonlandı."
fi

# 3. SSH Anahtar Çifti Kontrolü
echo "▶ 3. EC2 SSH Anahtar Çifti (novashop-key) kontrol ediliyor..."
mkdir -p ~/.ssh
if aws ec2 describe-key-pairs --key-names novashop-key --region "$AWS_DEFAULT_REGION" >/dev/null 2>&1; then
    echo "   ✓ 'novashop-key' anahtarı AWS üzerinde mevcut."
else
    echo "   + 'novashop-key' oluşturuluyor ve ~/.ssh/novashop-key.pem dosyasına kaydediliyor..."
    aws ec2 create-key-pair --key-name novashop-key --query "KeyMaterial" --output text \
        --region "$AWS_DEFAULT_REGION" > ~/.ssh/novashop-key.pem
    chmod 400 ~/.ssh/novashop-key.pem
    echo "   ✓ 'novashop-key' oluşturuldu (~/.ssh/novashop-key.pem)."
fi

# 4. Değişken Dosyası Kontrolü
if [ ! -f "terraform.tfvars" ]; then
    echo "▶ 4. 'terraform.tfvars' şablondan kopyalanıyor..."
    cp terraform.tfvars.example terraform.tfvars
fi

# 5. Terraform Init (Dinamik Backend Yapılandırması)
echo "▶ 5. Terraform S3 Backend ile başlatılıyor (init)..."
terraform init -reconfigure \
    -backend-config="bucket=$BUCKET_NAME" \
    -backend-config="region=$AWS_DEFAULT_REGION"

# 6. Terraform Apply
echo "▶ 6. Altyapı oluşturuluyor (apply)..."
terraform apply -auto-approve -var="aws_region=$AWS_DEFAULT_REGION"

echo "======================================================================"
echo "✅ Kurulum Tamamlandı! Erişim Bilgileri:"
echo "======================================================================"
terraform output
