#!/usr/bin/env bash
# ==============================================================================
# NovaShop LAB-00: Tüm DevOps Araçları Tek Komutla Kurulum Scripti
# ==============================================================================
# Bu script sıfır bir Ubuntu 22.04 / 24.04 LTS makinesine aşağıdaki araçları kurar:
# 1. Temel Sistem Paketleri (curl, wget, git, jq, unzip, tree, htop, net-tools vb.)
# 2. Docker CE, containerd.io, Docker Compose v2 & Buildx Plugin (Resmi Docker Deposu)
# 3. AWS CLI v2
# 4. HashiCorp Terraform
# 5. Kubernetes kubectl
# 6. Kind (Kubernetes in Docker)
# 7. Helm v3
# 8. Docker grup yetkilendirmesi ($USER, devopsadmin, student01)
# ==============================================================================
set -euo pipefail

echo "======================================================================"
echo "🚀 NovaShop LAB-00: DevOps Altyapı ve Platform Araçları Kurulumu"
echo "======================================================================"

# 0. Root yetkisi kontrolü
if [ "$EUID" -ne 0 ]; then
    SUDO="sudo"
else
    SUDO=""
fi

# 1. Temel Sistem Paketleri
echo "▶ 1. Temel sistem paketleri güncelleniyor ve kuruluyor..."
$SUDO apt-get update -y
$SUDO apt-get install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    software-properties-common \
    apt-transport-https \
    wget \
    git \
    jq \
    htop \
    net-tools \
    unzip \
    tar \
    tree \
    make

# 2. Docker CE, Containerd ve Docker Compose v2 (Resmi Docker Deposu)
echo "▶ 2. Docker CE ve Docker Compose v2 kuruluyor..."
$SUDO install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | $SUDO gpg --dearmor -o /etc/apt/keyrings/docker.gpg --yes
$SUDO chmod a+r /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | $SUDO tee /etc/apt/sources.list.d/docker.list > /dev/null

$SUDO apt-get update -y
$SUDO apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Docker servisini başlat ve aktif et
$SUDO systemctl enable --now docker

# Mevcut kullanıcıyı docker grubuna ekle
$SUDO usermod -aG docker "${SUDO_USER:-$USER}" 2>/dev/null || true
id -u devopsadmin >/dev/null 2>&1 && $SUDO usermod -aG docker devopsadmin || true
id -u student01 >/dev/null 2>&1 && $SUDO usermod -aG docker student01 || true

# 3. AWS CLI v2
echo "▶ 3. AWS CLI v2 kontrol ediliyor / kuruluyor..."
if ! command -v aws >/dev/null 2>&1; then
    TEMP_DIR=$(mktemp -d)
    curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "$TEMP_DIR/awscliv2.zip"
    unzip -q "$TEMP_DIR/awscliv2.zip" -d "$TEMP_DIR"
    $SUDO "$TEMP_DIR/aws/install" --update
    rm -rf "$TEMP_DIR"
    echo "   ✓ AWS CLI v2 başarıyla kuruldu."
else
    echo "   ✓ AWS CLI zaten kurulu: $(aws --version)"
fi

# 4. HashiCorp Terraform
echo "▶ 4. HashiCorp Terraform kontrol ediliyor / kuruluyor..."
if ! command -v terraform >/dev/null 2>&1; then
    wget -O- https://apt.releases.hashicorp.com/gpg | $SUDO gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg --yes
    echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | $SUDO tee /etc/apt/sources.list.d/hashicorp.list
    $SUDO apt-get update -y && $SUDO apt-get install -y terraform
    echo "   ✓ Terraform başarıyla kuruldu."
else
    echo "   ✓ Terraform zaten kurulu: $(terraform version | head -n 1)"
fi

# 5. Kubernetes kubectl (En Güncel Resmi Stable)
echo "▶ 5. Kubernetes kubectl kontrol ediliyor / kuruluyor..."
if ! command -v kubectl >/dev/null 2>&1; then
    K8S_VERSION=$(curl -L -s https://dl.k8s.io/release/stable.txt)
    echo "   En güncel stable kubectl indiriliyor ($K8S_VERSION)..."
    curl -fsSL "https://dl.k8s.io/release/${K8S_VERSION}/bin/linux/amd64/kubectl" -o /tmp/kubectl
    chmod +x /tmp/kubectl
    $SUDO mv /tmp/kubectl /usr/local/bin/kubectl
    echo "   ✓ kubectl ($K8S_VERSION) başarıyla kuruldu."
else
    echo "   ✓ kubectl zaten kurulu: $(kubectl version --client --output=yaml 2>/dev/null | grep gitVersion || kubectl version --client)"
fi

# 6. Kind (Kubernetes in Docker - En Güncel Resmi Stable)
echo "▶ 6. Kind kontrol ediliyor / kuruluyor..."
if ! command -v kind >/dev/null 2>&1; then
    KIND_VERSION=$(curl -s https://api.github.com/repos/kubernetes-sigs/kind/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
    echo "   En güncel stable Kind indiriliyor ($KIND_VERSION)..."
    curl -fsSL "https://kind.sigs.k8s.io/dl/${KIND_VERSION}/kind-linux-amd64" -o /tmp/kind
    chmod +x /tmp/kind
    $SUDO mv /tmp/kind /usr/local/bin/kind
    echo "   ✓ Kind ($KIND_VERSION) başarıyla kuruldu."
else
    echo "   ✓ Kind zaten kurulu: $(kind version)"
fi

# 7. Helm v3
echo "▶ 7. Helm v3 kontrol ediliyor / kuruluyor..."
if ! command -v helm >/dev/null 2>&1; then
    curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
    echo "   ✓ Helm v3 başarıyla kuruldu."
else
    echo "   ✓ Helm zaten kurulu: $(helm version --short)"
fi

echo "======================================================================"
echo "✅ LAB-00: Tüm Temel DevOps Platform Araçları Başarıyla Kuruldu!"
echo "======================================================================"
echo "Kurulum Özeti:"
echo " • Docker Engine : $(docker --version 2>/dev/null || echo 'Mevcut (yeniden oturum acilabilir)')"
echo " • Docker Compose: $(docker compose version 2>/dev/null || echo 'Compose eklentisi hazir')"
echo " • Containerd    : $(containerd --version 2>/dev/null || echo 'Kuruldu')"
echo " • AWS CLI       : $(aws --version 2>/dev/null || echo 'Kuruldu')"
echo " • Terraform     : $(terraform version 2>/dev/null | head -n 1 || echo 'Kuruldu')"
echo " • kubectl       : $(kubectl version --client --short 2>/dev/null || echo 'Kuruldu')"
echo " • Kind          : $(kind version 2>/dev/null || echo 'Kuruldu')"
echo " • Helm          : $(helm version --short 2>/dev/null || echo 'Kuruldu')"
echo "======================================================================"
echo "⚠️ ÖNEMLİ NOT: Docker grubunun mevcut terminalde hemen etkinleşmesi için:"
echo "    newgrp docker"
echo "komutunu çalıştırabilir veya terminalden çıkıp tekrar giriş yapabilirsiniz."
echo "======================================================================"
