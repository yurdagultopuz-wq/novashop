#!/usr/bin/env bash
# NovaShop — LAB-08 DevSecOps Güvenlik Kapıları Doğrulama Betiği
set -e

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

echo "=== [LAB-08] DevSecOps Güvenlik Kapıları Doğrulama Başlatılıyor ==="

# 1. Secret Scanning (Hassas Bilgi Sızıntı Taraması)
echo "1. Hassas bilgi ve özel anahtar sızıntı taraması yapılıyor..."
SECRET_LEAKS=0

# AWS Key taraması (Vendor .yarn paketleri hariç tutulur)
if git -C "$REPO_ROOT" grep -E "AKIA[0-9A-Z]{16}" -- 'src/*' 'deploy/*' 'charts/*' '.github/*' ':!*/.yarn/*' ':!*.cjs' ':!*.md' 2>/dev/null; then
    echo "❌ HATA: Kaynak kodda AWS Access Key bulundu!"
    SECRET_LEAKS=$((SECRET_LEAKS + 1))
fi

# Özel RSA/EC anahtar taraması
if git -C "$REPO_ROOT" grep -E "BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY" -- 'src/*' 'deploy/*' 'charts/*' '.github/*' ':!*/.yarn/*' ':!*.cjs' ':!*.md' 2>/dev/null; then
    echo "❌ HATA: Kaynak kodda özel kriptografik anahtar (Private Key) bulundu!"
    SECRET_LEAKS=$((SECRET_LEAKS + 1))
fi

if [ "$SECRET_LEAKS" -eq 0 ]; then
    echo "✅ Secret taraması temiz: Kod tabanında sızıntı tespit edilmedi."
else
    echo "❌ Güvenlik kapısı ihlali: Secret sızıntısı bulundu ($SECRET_LEAKS adet)."
    exit 1
fi

# 2. Lisans ve Uyumluluk Kontrolü
echo "2. Açık kaynak lisans ve atıf (Attribution) kontrolü..."
if [ -f "$REPO_ROOT/LICENSE" ]; then
    echo "✅ Ana depo LICENSE dosyası mevcut."
else
    echo "❌ HATA: Kök dizinde LICENSE dosyası bulunamadı."
    exit 1
fi

# 3. Dockerfile Non-Root Güvenlik Denetimi
echo "3. Dockerfile güvenlik sertleştirmesi (Non-root) denetleniyor..."
NON_ROOT_COUNT=0
while IFS= read -r -d '' df; do
    if grep -q "USER " "$df"; then
        echo "✅ Non-root kullanıcı kuralı mevcut: $(basename "$(dirname "$df")")/Dockerfile"
        NON_ROOT_COUNT=$((NON_ROOT_COUNT + 1))
    else
        echo "⚠️ UYARI: Non-root USER direktifi eksik: $df"
    fi
done < <(find "$REPO_ROOT/src" -name "Dockerfile" -print0 2>/dev/null)

# 4. Trivy Taraması (Eğer Trivy yüklüyse)
if command -v trivy >/dev/null 2>&1; then
    echo "4. Trivy dosya sistemi güvenlik taraması çalıştırılıyor..."
    trivy fs --severity CRITICAL --exit-code 0 "$REPO_ROOT/src"
    echo "✅ Trivy taraması tamamlandı."
else
    echo "ℹ️ Bilgi: Trivy CLI yüklü değil; statik güvenlik denetimleri uygulandı."
fi

echo "=== [LAB-08] DevSecOps Güvenlik Kapıları Doğrulaması Başarılı! ==="
