# Platform Hazırlık 02 — Harbor OCI Registry ve Trivy Kurulumu

Harbor; kurumsal ölçekte konteyner imajlarını depolamak, güvenlik açıklarını (Trivy ile) taramak ve imaj yaşam döngüsünü yönetmek için kullanılan kurumsal düzeyde bir açık kaynak OCI Registry platformudur.

Bu rehber, sunucunuzda `/opt/harbor` veya Harbor bileşenleri **hiç bulunmasa bile** sıfırdan adım adım kurulum yapmanızı sağlar ve iki farklı erişim modelini destekler:
1. **Model A (Lokal / Doğrudan IP:Port):** DNS ve SSL olmadan doğrudan `http://<UBUNTU_IP>:18444` (veya `18082`) ile kullanım.
2. **Model B (Kurumsal DNS + SSL):** Nginx Edge arkasında `https://student100-harbor.devopsatolyesi.com` ile kullanım.

---

## Genel Bakış ve Port Yapılandırması

* **Dahili Harbor HTTP Portu:** `18444` / `18082` (Nginx 80/443 portlarıyla çakışmaz)
* **Dahili Güvenlik Tarayıcısı:** Trivy Scanner etkin
* **Varsayılan Giriş Bilgileri:**
  * **Kullanıcı:** `admin`
  * **Şifre:** `Harbor12345`

---

## Ön Koşul: Docker ve Docker Compose Kontrolü

Sıfır bir Ubuntu makinesinde Docker Engine ve Docker Compose v2 eklentisinin kurulu olduğundan emin olun:

```bash
# Docker ve Compose kurulu değilse:
sudo apt-get update
sudo apt-get install -y ca-certificates curl docker.io docker-compose-plugin
sudo usermod -aG docker $USER
```

Kurulumu doğrulayın:
```bash
docker --version
docker compose version
```

---

## Ana Yöntem: Adım Adım Manuel Kurulum

### Adım 1: Kurulum Dizinini Oluşturma ve Paketi İndirme

Harbor kurulum dosyalarını `/opt/harbor` dizinine açacağız:

```bash
# 1. Kurulum dizinini oluşturun
sudo mkdir -p /opt/harbor

# 2. Geçici dizine geçip Harbor Online Installer paketini indirin
cd /tmp
curl -fSLo harbor-online-installer-v2.10.0.tgz \
  https://github.com/goharbor/harbor/releases/download/v2.10.0/harbor-online-installer-v2.10.0.tgz

# 3. Paketi /opt dizinine açın (içerik /opt/harbor olarak açılır)
sudo tar -xzf harbor-online-installer-v2.10.0.tgz -C /opt/
cd /opt/harbor
```

---

### Adım 2: Yapılandırma Dosyasını (`harbor.yml`) Hazırlama

Harbor'ı dahili olarak port `18082` HTTP modunda çalıştıracağız:

1. Örnek şablonu kopyalayın:
   ```bash
   sudo cp /opt/harbor/harbor.yml.tmpl /opt/harbor/harbor.yml
   ```

2. Sunucu yerel IP adresinizi öğrenin:
   ```bash
   LOCAL_IP=$(hostname -I | awk '{print $1}')
   echo "Sunucu IP: $LOCAL_IP"
   ```

3. `harbor.yml` dosyasını HTTP 18082 moduna getirin:
   ```bash
   # Hostname ve port güncellemesi
   sudo sed -i "s/hostname: reg.mydomain.com/hostname: ${LOCAL_IP}/" /opt/harbor/harbor.yml
   sudo sed -i 's/port: 80/port: 18082/' /opt/harbor/harbor.yml

   # HTTPS bloğunu devre dışı bırakma (SSL'i gerekirse Nginx 443 çözecektir)
   sudo sed -i 's/^https:/#https:/' /opt/harbor/harbor.yml
   sudo sed -i 's/^  port: 443/#  port: 443/' /opt/harbor/harbor.yml
   sudo sed -i 's/^  certificate:/#  certificate:/' /opt/harbor/harbor.yml
   sudo sed -i 's/^  private_key:/#  private_key:/' /opt/harbor/harbor.yml
   ```

---

### Adım 3: Harbor Kurulumunu Başlatma (Trivy Dahil)

Kurulum betiğini Trivy zafiyet tarayıcısı ile çalıştırın:

```bash
cd /opt/harbor
sudo ./install.sh --with-trivy
```

**Konteynerlerin Durumunu Kontrol Etme:**
```bash
cd /opt/harbor
sudo docker compose ps
```
*Beklenen çıktı:* Tüm Harbor konteynerleri (`harbor-core`, `harbor-db`, `registry`, `trivy-adapter`, `nginx`) `Up (healthy)` durumunda olmalıdır.

---

### Adım 4: Web Arayüzünden `novashop` Projesini Açma

1. Tarayıcınızdan Harbor'a erişin:
   * **Doğrudan IP ile:** `http://<UBUNTU_IP>:18082`
   * **veya DNS/SSL ile:** `https://student100-harbor.devopsatolyesi.com`
2. Giriş yapın (`admin` / `Harbor12345`).
3. Sol menüden **Projects** -> **+ New Project** butonuna basın:
   * **Project Name:** `novashop`
   * **Access Level:** **Public** kutucuğunu işaretleyin (Böylece Kubernetes kümesi imaj çekerken k8s imagePullSecret gerektirmez).
   * **OK** butonuna basarak projeyi oluşturun.

---

## 🔐 İki Farklı Modelde Docker CLI Girişi ve İmaj Gönderimi

### Model A: DNS ve SSL Olmadığında (Lokal / Doğrudan IP Modu)

Harbor HTTP üzerinde çalıştığı için Docker daemon varsayılan olarak güvensiz registry bağlantısını engeller. Bunu aşmak için:

1. `/etc/docker/daemon.json` dosyasını oluşturun/güncelleyin:
   ```bash
   LOCAL_IP=$(hostname -I | awk '{print $1}')
   sudo mkdir -p /etc/docker
   cat << DAEMON_EOF | sudo tee /etc/docker/daemon.json
   {
     "insecure-registries": ["${LOCAL_IP}:18082", "127.0.0.1:18082", "localhost:18082"]
   }
   DAEMON_EOF

   sudo systemctl restart docker
   ```

2. Docker CLI ile giriş yapın ve test imajı gönderin:
   ```bash
   docker login ${LOCAL_IP}:18082 -u admin -p Harbor12345

   # Test imajı:
   docker pull alpine:latest
   docker tag alpine:latest ${LOCAL_IP}:18082/novashop/alpine:v1
   docker push ${LOCAL_IP}:18082/novashop/alpine:v1
   ```

3. **Kind Kümesi İçin Çözüm:**  
   Lokal Kind kümesi çalıştırıyorsanız imajı doğrudan node'lara aktararak ağ/insecure kısıtlarına takılmadan çalışabilirsiniz:
   ```bash
   kind load docker-image ${LOCAL_IP}:18082/novashop/alpine:v1 --name novashop-cluster
   ```

---

### Model B: Kurumsal DNS ve SSL Olduğunda (Nginx Edge Modu)

Eğer [05-nginx-ssl-setup.md](05-nginx-ssl-setup.md) adımı ile `student100` için SSL Edge ayağa kaldırıldıysa:

1. Docker CLI standart port 443 (HTTPS) üzerinden Harbor'a bağlanır:
   ```bash
   docker login student100-harbor.devopsatolyesi.com -u admin -p Harbor12345
   ```
   *(Hiçbir `daemon.json` veya `insecure-registries` ayarı gerektirmez!)*

2. İmajı güvenli alan adı ile etiketleyip gönderin:
   ```bash
   docker tag alpine:latest student100-harbor.devopsatolyesi.com/novashop/alpine:v1
   docker push student100-harbor.devopsatolyesi.com/novashop/alpine:v1
   ```

---

## Alternatif Yöntem: Hızlı Kurulum (Fast-Track Script)

Tüm dizin açma, indirme, IP tespiti ve Trivy kurulumunu tek komutla tamamlamak için:

```bash
cd ~/novashop
sudo bash infra/harbor/install_harbor.sh
```

---

## Servisi Durdurma ve Başlatma (RAM Tasarrufu)

Harbor arka planda 8-9 konteyner çalıştırır (~1.5 GB RAM). Başka lablara geçtiğinizde RAM'i serbest bırakmak için:

```bash
# Durdurma:
cd /opt/harbor && sudo docker compose stop

# Yeniden başlatma:
cd /opt/harbor && sudo docker compose start
```
