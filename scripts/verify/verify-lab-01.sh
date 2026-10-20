#!/usr/bin/env bash
# NovaShop — LAB-01 Git ve GitHub Doğrulama Betiği
set -e

echo "=== [LAB-01] Doğrulama Başlatılıyor ==="

# 1. Git Repo Varlığı
if [ ! -d ".git" ]; then
    echo "❌ HATA: Mevcut dizin bir Git deposu değil (.git bulunamadı)."
    exit 1
fi
echo "✅ Git deposu mevcut."

# 2. Local Git Kullanıcı Ayarları
LOCAL_USER=$(git config --local user.name || true)
LOCAL_EMAIL=$(git config --local user.email || true)

if [ -z "$LOCAL_USER" ] || [ -z "$LOCAL_EMAIL" ]; then
    echo "⚠️ UYARI: Repo-local user.name veya user.email ayarlanmamış."
    echo "   Öneri: git config --local user.name \"Ad Soyad\" ve git config --local user.email \"email@example.com\""
else
    echo "✅ Local Git yapılandırması: $LOCAL_USER <$LOCAL_EMAIL>"
fi

# 3. Commit Geçmişi
COMMIT_COUNT=$(git rev-list --count HEAD 2>/dev/null || echo "0")
if [ "$COMMIT_COUNT" -eq 0 ]; then
    echo "❌ HATA: Henüz hiç commit yapılmamış."
    exit 1
fi
echo "✅ Toplam commit sayısı: $COMMIT_COUNT"

# 4. Temiz Çalışma Ağacı
UNTRACKED=$(git status --porcelain)
if [ -n "$UNTRACKED" ]; then
    echo "⚠️ Bilgi: Çalışma ağacında commit edilmemiş değişiklikler var:"
    echo "$UNTRACKED"
else
    echo "✅ Çalışma ağacı temiz (clean working tree)."
fi

echo "=== [LAB-01] Doğrulama Başarıyla Tamamlandı! ==="
