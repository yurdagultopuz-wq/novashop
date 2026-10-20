#!/usr/bin/env bash
# ==============================================================================
# NovaShop — Harbor OCI Registry ve Trivy Kurulum Betiği
# Port: 18082 (HTTP) | Varsayılan Kullanıcı: admin / Harbor12345
# Cockpit & Nginx Reverse Proxy Entegre: https://student01-harbor.devopsatolyesi.com
# ==============================================================================
set -euo pipefail

HARBOR_VERSION="v2.10.0"
INSTALL_DIR="/opt/harbor"
STUDENT_TAG="${1:-student01}"

echo "======================================================================"
echo "🚀 Harbor OCI Registry ve Trivy Kurulumu Başlatılıyor (${STUDENT_TAG})"
echo "======================================================================"

echo "===> [1/5] Sistem ve Docker Kontrolleri..."
if ! command -v docker &> /dev/null; then
    echo "❌ HATA: Docker motoru bulunamadı. Lütfen önce Docker'ı kurun."
    exit 1
fi

if ! docker compose version &> /dev/null; then
    echo "⚠️ Docker Compose V2 eklentisi bulunamadı, kuruluyor..."
    sudo apt-get update -y && sudo apt-get install -y docker-compose-plugin || true
fi

echo "===> [2/5] Kurulum Dizini Hazırlanıyor (${INSTALL_DIR})..."
sudo mkdir -p "${INSTALL_DIR}"
cd /tmp

INSTALLER_TAR="harbor-online-installer-${HARBOR_VERSION}.tgz"
if [ ! -f "${INSTALLER_TAR}" ] || [ $(wc -c < "${INSTALLER_TAR}") -lt 1000000 ]; then
    echo "===> Harbor ${HARBOR_VERSION} paketi indiriliyor..."
    rm -f "${INSTALLER_TAR}"
    curl -fSLo "${INSTALLER_TAR}" "https://github.com/goharbor/harbor/releases/download/${HARBOR_VERSION}/${INSTALLER_TAR}"
fi

echo "===> Paket ${INSTALL_DIR} dizinine açılıyor..."
sudo tar -xzf "${INSTALLER_TAR}" -C /opt/

echo "===> [3/5] harbor.yml Yapılandırması Hazırlanıyor (HTTP: 18082)..."
LOCAL_IP=$(hostname -I 2>/dev/null | awk '{print $1}' || echo "127.0.0.1")
PUBLIC_IP=$(curl -s -m 2 http://169.254.169.254/computeMetadata/v1/instance/network-interfaces/0/access-configs/0/external-ip -H "Metadata-Flavor: Google" 2>/dev/null || curl -s -m 2 ifconfig.me 2>/dev/null || echo "")

HARBOR_HOSTNAME="${STUDENT_TAG}-harbor.devopsatolyesi.com"

# Python ile güvenli harbor.yml oluşturma (HTTPS bloğunu tamamen kapatır)
if command -v python3 &>/dev/null; then
    sudo python3 - << PYEOF
with open("${INSTALL_DIR}/harbor.yml.tmpl", "r") as f:
    lines = f.readlines()
out = []
in_https = False
for line in lines:
    if line.startswith("hostname:"):
        out.append(f"hostname: ${HARBOR_HOSTNAME}\n")
    elif line.strip() == "port: 80":
        out.append("  port: 18082\n")
    elif line.startswith("https:"):
        in_https = True
        out.append("#" + line)
    elif in_https and (line.startswith("  ") or line.strip() == ""):
        out.append("#" + line if line.strip() else line)
    else:
        in_https = False
        out.append(line)
with open("${INSTALL_DIR}/harbor.yml", "w") as f:
    f.writelines(out)
PYEOF
else
    sudo cp "${INSTALL_DIR}/harbor.yml.tmpl" "${INSTALL_DIR}/harbor.yml"
    sudo sed -i "s/hostname: reg.mydomain.com/hostname: ${HARBOR_HOSTNAME}/" "${INSTALL_DIR}/harbor.yml"
    sudo sed -i 's/port: 80/port: 18082/' "${INSTALL_DIR}/harbor.yml"
    sudo sed -i 's/^https:/#https:/' "${INSTALL_DIR}/harbor.yml"
    sudo sed -i 's/^  port: 443/#  port: 443/' "${INSTALL_DIR}/harbor.yml"
    sudo sed -i 's/^  certificate:/#  certificate:/' "${INSTALL_DIR}/harbor.yml"
    sudo sed -i 's/^  private_key:/#  private_key:/' "${INSTALL_DIR}/harbor.yml"
fi

echo "===> [4/5] Docker Daemon Insecure Registry Tanımlanıyor..."
sudo mkdir -p /etc/docker
if [ -f /etc/docker/daemon.json ]; then
    sudo cp /etc/docker/daemon.json /etc/docker/daemon.json.bak
fi

cat << DOCKER_JSON | sudo tee /etc/docker/daemon.json
{
  "insecure-registries": [
    "127.0.0.1:18082",
    "localhost:18082",
    "${LOCAL_IP}:18082",
    "${HARBOR_HOSTNAME}",
    "${HARBOR_HOSTNAME}:18082"
  ]
}
DOCKER_JSON

# Local DNS yönlendirmesi ekle (Harbor token servisinin Cloudflare proxy'sine takılmasını önler)
if ! grep -q "${HARBOR_HOSTNAME}" /etc/hosts; then
    echo "127.0.0.1 ${HARBOR_HOSTNAME}" | sudo tee -a /etc/hosts >/dev/null
    echo "===> /etc/hosts içerisine 127.0.0.1 ${HARBOR_HOSTNAME} kaydı eklendi."
fi

sudo systemctl restart docker

echo "===> [5/5] Harbor Kurulumu Başlatılıyor (Trivy Dahil)..."
cd "${INSTALL_DIR}"
sudo ./install.sh --with-trivy

echo ""
echo "======================================================================"
echo "🎉 Harbor Private Registry Başarıyla Kuruldu!"
echo "======================================================================"
echo "🌐 Kurumsal SSL URL : https://${HARBOR_HOSTNAME}"
echo "🌐 Doğrudan IP URL  : http://${PUBLIC_IP:-$LOCAL_IP}:18082"
echo "👤 Kullanıcı Adı     : admin"
echo "🔑 Şifre             : Harbor12345"
echo ""
echo "Docker CLI Giriş Komutu:"
echo "  docker login 127.0.0.1:18082 -u admin -p Harbor12345"
echo "  veya"
echo "  docker login ${HARBOR_HOSTNAME} -u admin -p Harbor12345"
echo "======================================================================"
