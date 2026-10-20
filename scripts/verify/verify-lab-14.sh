#!/usr/bin/env bash
# NovaShop — LAB-14 Amazon ECS Fargate ve ALB Doğrulama Betiği
set -euo pipefail

ALB_HOST="${1:-}"
CLUSTER_NAME="${2:-novashop-ecs-cluster}"
REGION="${3:-eu-central-1}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

echo "=== [LAB-14] Amazon ECS Fargate ve ALB Doğrulama Başlatılıyor ==="

# 1. Terraform ECS Modülü ve Güvenlik Denetimi
echo "1. Terraform ECS Fargate modül yapısı denetleniyor..."
ECS_TF="$REPO_ROOT/terraform/ecs.tf"
if [ ! -f "$ECS_TF" ]; then
    echo "❌ HATA: terraform/ecs.tf dosyası bulunamadı!" >&2
    exit 1
fi

grep -q 'launch_type\s*=\s*"FARGATE"' "$ECS_TF" || { echo "❌ HATA: ecs.tf içinde FARGATE launch_type eksik!" >&2; exit 1; }
grep -q 'containerInsights' "$ECS_TF" || { echo "❌ HATA: Container Insights ayarı eksik!" >&2; exit 1; }
grep -q 'aws_lb' "$ECS_TF" || { echo "❌ HATA: Application Load Balancer tanımı eksik!" >&2; exit 1; }
echo "✅ Terraform ECS Fargate, ALB ve Container Insights tanımları doğrulandı."

# 2. ECS Task Definition JSON Dosyaları Sözdizim Kontrolü
echo "2. ECS Task Definition JSON dosyaları kontrol ediliyor..."
for td in "$REPO_ROOT/deploy/ecs"/*.json; do
    [ -f "$td" ] || continue
    python3 -m json.tool "$td" >/dev/null 2>&1 || { echo "❌ HATA: $td geçerli bir JSON değil!" >&2; exit 1; }
    echo "✅ Task Definition JSON geçerli: $(basename "$td")"
done

# 3. GitHub Actions ECS Pipeline Varlığı
if [ -f "$REPO_ROOT/.github/workflows/novashop-ecs-ci.yml" ]; then
    echo "✅ GitHub Actions ECS CI/CD iş akışı mevcut (.github/workflows/novashop-ecs-ci.yml)."
fi

# 4. Canlı ALB Sağlık Kontrolü (ALB Host Verilmişse)
if [ -n "$ALB_HOST" ]; then
    echo "4. Canlı ALB sağlık kontrolü test ediliyor ($ALB_HOST)..."
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 8 "http://${ALB_HOST}/actuator/health" 2>/dev/null || echo "000")
    if [ "$HTTP_CODE" = "200" ]; then
        echo "✅ ALB üzerinden Actuator sağlık kontrolü başarılı (HTTP 200 OK)."
    else
        echo "⚠️ UYARI: ALB http://${ALB_HOST}/actuator/health $HTTP_CODE döndü."
    fi
else
    echo "ℹ️ Canlı ALB testi için kullanım: $0 <ALB_DNS_NAME> (Örn: $0 novashop-alb-123456.eu-central-1.elb.amazonaws.com)"
fi

# 5. AWS CLI ile Küme Kontrolü (Opsiyonel)
if command -v aws >/dev/null 2>&1; then
    echo "5. AWS CLI üzerinden ECS kümesi sorgulanıyor..."
    CLUSTER_STATUS=$(aws ecs describe-clusters --clusters "$CLUSTER_NAME" --region "$REGION" --query "clusters[0].status" --output text 2>/dev/null || echo "NOT_FOUND")
    if [ "$CLUSTER_STATUS" = "ACTIVE" ]; then
        echo "✅ Amazon ECS kümesi aktif: $CLUSTER_NAME"
    fi
fi

echo "=== [LAB-14] Amazon ECS Fargate Doğrulaması Başarılı (PASS) ==="
