# LAB-00 — Platform Kurulumu ve DevOps Araçları Hazırlığı

Bu modül, kurumsal DevOps laboratuvarlarında kullanılacak temel araçların (**Docker CE, Containerd, Docker Compose v2, AWS CLI v2, Terraform, kubectl, Kind, Helm, GitLab CE, Harbor OCI Registry, SonarQube, Jenkins ve Nginx Reverse Proxy**) sıfır bir Ubuntu sunucusu üzerinde adım adım ve kendi kendine yeten biçimde kurulmasını kapsar.

---

## Temel İlkeler ve Yaklaşım

1. **Sıfır Sunucu Varsayımı:** Sunucuda `/opt/harbor` veya benzeri dizinler ya da araçlar önceden kurulu olmak zorunda değildir. Her rehber, sıfır bir Ubuntu sanal makinesinde baştan sona çalışacak şekilde tasarlanmıştır.
2. **Çift Erişim Modeli (Dual Mode):**
   * **Model A (Doğrudan IP:Port — Standart & Varsayılan):** DNS ve SSL zorunluluğu olmadan doğrudan `http://<UBUNTU_IP>:<PORT>` ile çalışır.
   * **Model B (Kurumsal DNS + Wildcard SSL):** Sunucuya DNS tahsis edildiğinde (`student01` gibi) tek komutla Nginx 443 SSL ayağa kalkar.
   * **Önemli:** Model B aktif olsa bile Model A (doğrudan IP:Port erişimi) asla kapanmaz; iki model eşzamanlı çalışır.
3. **Sıfır `.env` Hatası:** Yapılandırmalar harici eksik `.env` dosyalarına bağımlı değildir; tüm çevre değişkenleri varsayılan değerlerle gömülüdür.
4. **Bellek (RAM) Yönetimi:** Tüm araçları aynı anda çalıştırmak zorunda değilsiniz. İlgili laba geçildiğinde aracı başlatıp, lab bitiminde durdurarak (`docker compose stop`) RAM tasarrufu sağlayabilirsiniz.

---

## Hızlı Başlangıç: Tek Komutla Otomatik Kurulum Scripti

Tüm temel sistem paketlerini, Docker ekosistemini, AWS CLI, Terraform ve Kubernetes araçlarını tek seferde kurmak için:

```bash
cd ~/novashop/labs/LAB-00-PLATFORM-SETUP
sudo ./install-devops-tools.sh
newgrp docker
```

---

## Sıfır Sunucu Temel Hazırlığı (Adım Adım Manuel Kurulum)

### Adım 0.1: Temel Ubuntu Paketlerini Güncelleme ve Kurma
```bash
sudo apt-get update
sudo apt-get install -y \
    ca-certificates curl gnupg lsb-release \
    software-properties-common apt-transport-https \
    wget git jq htop net-tools unzip tar tree make
```

---

### Adım 0.2: Resmi Docker CE, Containerd ve Docker Compose v2 Kurulumu
Ubuntu'nun eski `docker.io` paketi yerine Docker'ın en güncel resmi reposu kullanılır:

```bash
# 1. Docker resmi GPG anahtarını ekleyin
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# 2. Docker deposunu APT kaynaklarına tanımlayın
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# 3. Paket listesini güncelleyip Docker, containerd ve Compose'u kurun
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# 4. Docker servisini başlatın ve açılışa ekleyin
sudo systemctl enable --now docker

# 5. Mevcut kullanıcıyı docker grubuna ekleyin (sudo'suz çalıştırmak için)
sudo usermod -aG docker $USER
sudo usermod -aG docker devopsadmin 2>/dev/null || true
sudo usermod -aG docker student01 2>/dev/null || true

# 6. Grup yetkisini geçerli kılın (veya oturumu kapatıp açın)
newgrp docker
```

*Doğrulama:*
```bash
docker --version
docker compose version
docker run --rm hello-world
```

---

### Adım 0.3: AWS CLI v2 Kurulumu
LAB-02 ve Cloud entegrasyonları için AWS CLI v2 gereklidir:

```bash
cd /tmp
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip -q awscliv2.zip
sudo ./aws/install --update
rm -rf aws awscliv2.zip
cd -
```

*Doğrulama:*
```bash
aws --version
```

---

### Adım 0.4: HashiCorp Terraform Kurulumu
IaC altyapı dağıtımları için resmi HashiCorp Terraform reposu kullanılır:

```bash
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg --yes
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt-get update && sudo apt-get install -y terraform
```

*Doğrulama:*
```bash
terraform -version
```

---

### Adım 0.5: Kubernetes Ekosistemi (kubectl, Kind, Helm) Kurulumu (En Güncel Stable)
K8s, GitOps ve Helm laboratuvarları (LAB-06, LAB-08, LAB-09) için en güncel kararlı sürümler kurulur:

```bash
# 1. kubectl (En Güncel Resmi Stable Sürüm)
K8S_VERSION=$(curl -L -s https://dl.k8s.io/release/stable.txt)
curl -fsSL "https://dl.k8s.io/release/${K8S_VERSION}/bin/linux/amd64/kubectl" -o /tmp/kubectl
chmod +x /tmp/kubectl
sudo mv /tmp/kubectl /usr/local/bin/kubectl

# 2. Kind (Kubernetes in Docker - En Güncel GitHub Stable Sürüm)
KIND_VERSION=$(curl -s https://api.github.com/repos/kubernetes-sigs/kind/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
curl -fsSL "https://kind.sigs.k8s.io/dl/${KIND_VERSION}/kind-linux-amd64" -o /tmp/kind
chmod +x /tmp/kind
sudo mv /tmp/kind /usr/local/bin/kind

# 3. Helm v3 (Resmi Otomatik Kurulum - En Güncel Stable)
curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
```

*Doğrulama:*
```bash
kubectl version --client
kind version
helm version --short
```

---

## DevOps Platform Araçları, Port ve Erişim Haritası (Örnek: `student01`)

| Araç | Kurulum Rehberi | Model A: Doğrudan IP:Port | Model B: DNS + SSL (HTTPS) | RAM Tüketimi | Hızlı Başlatma |
| :--- | :--- | :--- | :--- | :---: | :--- |
| **NovaShop UI** | [LAB-06](../LAB-06/README.md) | `http://<UBUNTU_IP>:19001` (veya `8888`) | `https://student01-novashop.<DOMAIN_NAME>` | ~512 MB | Helm / Kind |
| **Harbor Registry** | [02-harbor-setup.md](02-harbor-setup.md) | `http://<UBUNTU_IP>:18444` (veya `18082`) | `https://student01-harbor.<DOMAIN_NAME>` | ~1.5 GB | `sudo bash infra/harbor/install_harbor.sh` |
| **GitLab CE** | [01-gitlab-setup.md](01-gitlab-setup.md) | `http://<UBUNTU_IP>:18929` (veya `8929`) | `https://student01-gitlab.<DOMAIN_NAME>` | ~3.5 GB | `docker compose -f infra/gitlab/docker-compose.yml up -d` |
| **SonarQube** | [03-sonarqube-setup.md](03-sonarqube-setup.md) | `http://<UBUNTU_IP>:19000` | `https://student01-sonar.<DOMAIN_NAME>` | ~2.0 GB | `docker compose -f infra/sonarqube/docker-compose.yml up -d` |
| **Jenkins** | [04-jenkins-setup.md](04-jenkins-setup.md) | `http://<UBUNTU_IP>:18080` | `https://student01-jenkins.<DOMAIN_NAME>` | ~1.0 GB | `docker compose -f infra/jenkins/docker-compose.yml up -d` |
| **Argo CD** | [LAB-08](../LAB-08/README.md) | `http://<UBUNTU_IP>:18082` (veya `8080`) | `https://student01-argocd.<DOMAIN_NAME>` | ~512 MB | `bash scripts/deploy-argocd.sh` |
| **Headlamp K8s**| [LAB-06](../LAB-06/README.md) | `http://<UBUNTU_IP>:18084` | `https://student01-headlamp.<DOMAIN_NAME>` | ~256 MB | Port-Forward / NodePort |
| **Kibana (ELK)**| [LAB-11](../LAB-11/README.md) | `http://<UBUNTU_IP>:15601` (veya `5601`) | `https://student01-kibana.<DOMAIN_NAME>` | ~1.0 GB | `docker compose -f deploy/logging/docker-compose.logging.yml up -d` |
| **Nginx Proxy** | [05-nginx-ssl-setup.md](05-nginx-ssl-setup.md) | - | `80/443 (Edge TLS)` | ~100 MB | `sudo bash infra/nginx/setup-ssl-edge.sh student01` |

---

## Kurumsal DNS ve SSL Aktivasyonu (Örnek: `student01`)

Eğer başlangıçta size bir kullanıcı kodu (örneğin `student01`) ve alan adı tahsis edildiyse, Nginx Edge ve Wildcard Origin SSL sertifikasını tek komutla aktifleştirebilirsiniz:

```bash
cd ~/novashop
sudo bash infra/nginx/setup-ssl-edge.sh student01
```

Bu komuttan sonra yukarıdaki tabloda yer alan tüm servis adresleri HTTPS üzerinden yayına başlayacaktır.

---

## Kaynak Tasarrufu Pratiği (Start / Stop)

Laboratuvar sanal makinenizin RAM sınırlarını zorlamamak için işiniz biten araçları durdurun:

```bash
# Servisi durdurma (Veriler volume'de kalır):
cd ~/novashop/infra/<servis_adi> && docker compose stop

# Servisi yeniden başlatma:
cd ~/novashop/infra/<servis_adi> && docker compose start
```
