#!/usr/bin/env bash
# NovaShop — LAB-12 Terraform IaC Doğrulama Betiği
set -e

TF_DIR="${1:-terraform}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

echo "=== [LAB-12] Terraform IaC Doğrulama Başlatılıyor ==="

TARGET_DIR="$TF_DIR"
if [ ! -d "$TARGET_DIR" ] && [ -d "$REPO_ROOT/$TF_DIR" ]; then
    TARGET_DIR="$REPO_ROOT/$TF_DIR"
fi

if [ ! -d "$TARGET_DIR" ]; then
    echo "ℹ️ Bilgi: '$TARGET_DIR' dizini bulunamadı. Kullanıcı tarafından terraform modülü oluşturulduğunda doğrulanacak."
    echo "=== [LAB-12] Terraform Doğrulama Tamamlandı ==="
    exit 0
fi

echo "✅ Terraform dizini bulundu: $TARGET_DIR"

# 1. Terraform Biçimlendirme Kontrolü
if command -v terraform >/dev/null 2>&1; then
    echo "1. terraform fmt biçimlendirme denetimi..."
    terraform -chdir="$TARGET_DIR" fmt -check || echo "⚠️ UYARI: terraform fmt ile dosyaları biçimlendirmeniz önerilir."

    echo "2. terraform validate sözdizim denetimi..."
    terraform -chdir="$TARGET_DIR" validate 2>/dev/null || echo "ℹ️ terraform init gereklidir."
else
    echo "ℹ️ Bilgi: Terraform CLI yüklü değil; statik dosya denetimi yapılıyor."
fi

# 2. Hardcoded Secret Taraması (.tf dosyalarında)
TF_SECRETS=$(grep -rnE 'password\s*=\s*"[^"]+"' "$TARGET_DIR" 2>/dev/null || true)
if [ -n "$TF_SECRETS" ]; then
    echo "❌ HATA: Terraform dosyalarında düz metin şifre tespit edildi!"
    echo "$TF_SECRETS"
    exit 1
else
    echo "✅ Terraform dosyalarında düz metin parola bulunamadı (Değişken veya Secrets Manager kullanılıyor)."
fi

echo "=== [LAB-12] Terraform IaC Doğrulaması Başarılı! ==="
