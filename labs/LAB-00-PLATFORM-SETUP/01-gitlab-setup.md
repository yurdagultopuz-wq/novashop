# Platform Hazırlık 01 — GitLab CE Kurulumu ve Yapılandırması

GitLab Community Edition (CE); kurumsal kaynak kod yönetimi (SCM), code review (Merge Request), issue takibi ve dahili GitLab CI/CD boru hatlarını çalıştırmak için kullanılan hepsi-bir-arada DevOps platformudur.

Bu rehber, sunucunuzda hiçbir yapılandırma olmasa bile sıfırdan adım adım GitLab CE kurulumunu ve RAM optimizasyonlarını açıklar.

---

## Genel Bakış ve Port Yapılandırması

Ubuntu sunucusunda port 80 ve 443 genel Nginx Reverse Proxy'ye ayrılmıştır. Çakışmayı önlemek için:
* **Web Arayüzü (HTTP):** `18929` (veya `8929`) portuna eşlenir.
* **Git SSH Portu:** `2224` portuna eşlenir (Sunucunun kendi SSH 22 portunu işgal etmez).
* **Varsayılan Yönetici Kullanıcısı:** `root`

---

## Ön Koşul: Docker ve Docker Compose Kontrolü

Sıfır bir makinede Docker Engine ve Compose eklentisini kurun:

```bash
sudo apt-get update
sudo apt-get install -y ca-certificates curl docker.io docker-compose-plugin
sudo usermod -aG docker $USER
```

---

## Ana Yöntem: Adım Adım Manuel Kurulum

### Adım 1: Çalışma Dizinini Oluşturma

GitLab yapılandırma ve veri dosyaları için dizin hazırlayın:

```bash
mkdir -p ~/novashop/infra/gitlab
cd ~/novashop/infra/gitlab
```

---

### Adım 2: Docker Compose Dosyasını Hazırlama

GitLab CE varsayılan haliyle 4-6 GB RAM tüketebilir. Sanal makinede kaynakları verimli kullanmak için optimize edilmiş `docker-compose.yml` dosyasını oluşturun:

```bash
cat << 'COMPOSE_EOF' > docker-compose.yml
services:
  gitlab:
    image: gitlab/gitlab-ce:latest
    container_name: gitlab-ce
    restart: always
    hostname: 'gitlab.novashop.local'
    environment:
      GITLAB_OMNIBUS_CONFIG: |
        external_url 'http://localhost:8929'
        gitlab_rails['gitlab_shell_ssh_port'] = 2224
        # RAM Tasarrufu: Puma iş parçacıklarını ve Sidekiq eşzamanlılığını sınırla (~2.5 GB tasarruf)
        puma['worker_processes'] = 2
        puma['min_threads'] = 1
        puma['max_threads'] = 4
        sidekiq['concurrency'] = 5
        prometheus_monitoring['enable'] = false
    ports:
      - "8929:8929"
      - "2224:22"
    volumes:
      - gitlab_config:/etc/gitlab
      - gitlab_logs:/var/log/gitlab
      - gitlab_data:/var/opt/gitlab
    shm_size: '256m'

volumes:
  gitlab_config:
  gitlab_logs:
  gitlab_data:
COMPOSE_EOF
```

---

### Adım 3: GitLab Konteynerini Başlatma

Konteyneri arka planda başlatın:

```bash
docker compose up -d
```

> [!NOTE]
> GitLab ilk başlatıldığında PostgreSQL veritabanı şemalarını ve yapılandırmasını tamamlaması **2-3 dakika** sürer. Başlatma sürecini takip etmek için:
> ```bash
> docker logs -f gitlab-ce
> ```
> `gitlab Reconfigured!` mesajını gördüğünüzde servis hazır demektir (`Ctrl+C` ile logdan çıkabilirsiniz).

---

### Adım 4: İlk Yönetici (root) Şifresini Alma

GitLab başladığında rastgele güçlü bir root şifresi üretir ve bu dosyada 24 saat saklar:

```bash
docker exec -it gitlab-ce grep 'Password:' /etc/gitlab/initial_root_password
```

**Giriş Bilgileri:**
* **Kullanıcı:** `root`
* **Şifre:** Yukarıdaki komutun çıktısında yer alan parola

---

### Adım 5: Web Arayüzüne Erişim

#### Model A: Doğrudan IP ile Erişim (DNS'siz)
```text
http://<UBUNTU_IP>:18929 (veya 8929)
```

#### Model B: Kurumsal DNS ve SSL ile Erişim
```text
https://student100-gitlab.devopsatolyesi.com
```

---

### Adım 6: Git SSH Kullanımı (Önemli Not)

GitLab'a SSH üzerinden kod push ederken port `2224` kullanıldığı için SSH klonlama adresiniz şu formatta olacaktır:
```bash
git clone ssh://git@<UBUNTU_IP>:2224/root/novashop.git
```

---

## Alternatif Yöntem: Hızlı Kurulum (Fast-Track)

Repo içindeki hazır compose dosyasını tek komutla çalıştırmak için:

```bash
cd ~/novashop
docker compose -f infra/gitlab/docker-compose.yml up -d
```

---

## Servisi Durdurma ve Başlatma (RAM Tasarrufu)

GitLab çalışırken ~3.5 GB RAM kullanır. Başka bir laba geçtiğinizde kaynakları serbest bırakmak için:

```bash
# Servisi durdurun (Kodlarınız ve verileriniz Docker volume'lerinde korunur):
cd ~/novashop/infra/gitlab && docker compose stop

# Tekrar ihtiyaç duyduğunuzda:
cd ~/novashop/infra/gitlab && docker compose start
```
