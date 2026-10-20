# Platform Hazırlık 03 — SonarQube ve PostgreSQL Kurulumu

SonarQube; statik kod analizi (SAST), kod kalitesi, güvenlik açıkları (vulnerabilities), kod kokuları (code smells) ve test kapsamını (coverage) ölçmek için kurulan kurumsal kod denetim platformudur.

Bu rehber, sunucunuzda hiçbir ön kurulum olmasa dahi sıfırdan adım adım SonarQube ve PostgreSQL veritabanını ayağa kaldırmanızı sağlar.

---

## Genel Bakış ve Port Yapılandırması

* **Web Arayüzü Portu (HTTP):** `19000` (Container içindeki 9000 portuna eşlenir)
* **Veritabanı:** PostgreSQL 15-alpine
* **Varsayılan Giriş:**
  * **Kullanıcı:** `admin`
  * **Şifre:** `admin` *(İlk girişte sistem yeni bir şifre belirlemenizi zorunlu tutar)*

---

## Ön Koşul 1: Docker ve Compose Kontrolü

Sıfır bir makinede Docker ve Compose'un kurulu olduğundan emin olun:

```bash
sudo apt-get update
sudo apt-get install -y ca-certificates curl docker.io docker-compose-plugin
sudo usermod -aG docker $USER
```

---

## Ön Koşul 2: Linux Çekirdek (Kernel) Ayarı

> [!IMPORTANT]
> SonarQube'un arama motoru olan **Elasticsearch**, Linux çekirdeğinde `vm.max_map_count` değerinin en az `262144` olmasını şart koşar. Bu ayar yapılmazsa SonarQube konteyneri anında çöker (`exit code 78`).

Sunucuda şu komutu çalıştırarak değeri yükseltin:

```bash
# Canlı oturum için anında uygula:
sudo sysctl -w vm.max_map_count=524288

# Sunucu yeniden başlasa da kalıcı olması için:
echo "vm.max_map_count=524288" | sudo tee -a /etc/sysctl.conf
```

---

## Ana Yöntem: Adım Adım Manuel Kurulum

### Adım 1: Çalışma Dizinini Oluşturma

```bash
mkdir -p ~/novashop/infra/sonarqube
cd ~/novashop/infra/sonarqube
```

---

### Adım 2: Docker Compose Dosyasını Hazırlama

Herhangi bir harici `.env` dosyasına ihtiyaç duymayan, kendi kendine yeten (self-contained) `docker-compose.yml` dosyasını oluşturun:

```bash
cat << 'COMPOSE_EOF' > docker-compose.yml
services:
  sonarqube:
    image: sonarqube:community
    container_name: sonarqube
    restart: always
    depends_on:
      - sonarqube_db
    ports:
      - "19000:9000"
    environment:
      - SONAR_JDBC_USERNAME=sonar
      - SONAR_JDBC_PASSWORD=sonar_secure_pass_454
      - SONAR_JDBC_URL=jdbc:postgresql://sonarqube_db:5432/sonar
    volumes:
      - sonarqube_data:/opt/sonarqube/data
      - sonarqube_extensions:/opt/sonarqube/extensions
      - sonarqube_logs:/opt/sonarqube/logs
    ulimits:
      nofile:
        soft: 65536
        hard: 65536

  sonarqube_db:
    image: postgres:15-alpine
    container_name: sonarqube-db
    restart: always
    environment:
      - POSTGRES_USER=sonar
      - POSTGRES_PASSWORD=sonar_secure_pass_454
      - POSTGRES_DB=sonar
    volumes:
      - sonarqube_db_data:/var/lib/postgresql/data

volumes:
  sonarqube_data:
  sonarqube_extensions:
  sonarqube_logs:
  sonarqube_db_data:
COMPOSE_EOF
```

---

### Adım 3: Konteynerleri Başlatma

```bash
docker compose up -d
```

Durumu kontrol edin:
```bash
docker ps --filter "name=sonarqube"
```
*Beklenen çıktı:* `sonarqube` ve `sonarqube-db` konteynerleri `Up` durumunda olmalıdır. SonarQube servisinin Java motorunu başlatıp hazır hale gelmesi yaklaşık 1 dakika sürebilir.

---

### Adım 4: Web Arayüzüne Erişim ve İlk Giriş

#### Model A: Doğrudan IP ile Erişim
```text
http://<UBUNTU_IP>:19000
```

#### Model B: Kurumsal DNS ve SSL ile Erişim
```text
https://student100-sonarqube.devopsatolyesi.com
```

1. Giriş bilgileriyle oturum açın:
   * **Login:** `admin`
   * **Password:** `admin`
2. İlk girişte şifre değiştirme ekranı gelir. Güçlü bir parola belirleyin (Örn: `Sonar12345!`).

---

## Alternatif Yöntem: Hızlı Kurulum (Fast-Track)

Çekirdek ayarını yaptıktan sonra repo içindeki hazır yapılandırmayı tek komutla başlatabilirsiniz:

```bash
sudo sysctl -w vm.max_map_count=524288
cd ~/novashop
docker compose -f infra/sonarqube/docker-compose.yml up -d
```

---

## Servisi Durdurma ve Başlatma (RAM Tasarrufu)

SonarQube ve PostgreSQL toplamda ~2 GB RAM tüketir. Çalışmadığınız lablarda RAM'i boşaltmak için:

```bash
# Servisleri durdurun (Tüm projeleriniz ve analizleriniz volume'lerde saklanır):
cd ~/novashop/infra/sonarqube && docker compose stop

# Tekrar ihtiyaç duyduğunuzda:
cd ~/novashop/infra/sonarqube && docker compose start
```
