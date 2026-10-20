#!/bin/bash
# ==============================================================================
# NovaShop EC2 Başlatma Betiği (User Data)
# Ubuntu 22.04 LTS üzerinde Docker Engine ve Docker Compose Plugin Kurulumu
# ==============================================================================
set -e
export DEBIAN_FRONTEND=noninteractive

echo "=== 1. Paket Listesi Güncelleniyor ==="
apt-get update -y
apt-get install -y ca-certificates curl gnupg git

echo "=== 2. Docker Resmi GPG Anahtarı ve Reposu Ekleniyor ==="
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

echo "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" > /etc/apt/sources.list.d/docker.list

echo "=== 3. Docker Engine ve Compose Plugin Kuruluyor ==="
apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

echo "=== 4. Kullanıcı Yetkileri ve Dağıtım Dizini Hazırlanıyor ==="
usermod -aG docker ubuntu
mkdir -p /home/ubuntu/novashop-deploy
chown -R ubuntu:ubuntu /home/ubuntu/novashop-deploy

echo "=== 5. Kurulum Başarıyla Tamamlandı ===" > /home/ubuntu/setup.log
