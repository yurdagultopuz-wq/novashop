# Platform Hazırlık 04 — Jenkins Controller Kurulumu

Jenkins; sürekli entegrasyon ve sürekli dağıtım (CI/CD) boru hatlarını otomatikleştirmek, Docker imajları derlemek ve mikroservis dağıtım adımlarını tetiklemek için kullanılan endüstri standardı açık kaynak otomasyon sunucusudur.

Bu rehber, sunucunuzda hiçbir ön kurulum olmasa dahi sıfırdan adım adım Jenkins Controller'ı Docker-in-Docker (Docker soket erişimi) yeteneği ile ayağa kaldırmanızı sağlar.

---

## Genel Bakış ve Port Yapılandırması

* **Web Arayüzü Portu (HTTP):** `18080` (Konteyner içindeki 8080 portuna eşlenir)
* **Jenkins Agent İletişim Portu (JNLP):** `50000`
* **Docker Soket Erişimi:** Host üzerindeki `/var/run/docker.sock` bağlanarak Jenkins'in doğrudan Docker komutları (`docker build`, `docker push`) koşturabilmesi sağlanır.

---

## Ön Koşul: Docker ve Docker Compose Kontrolü

Sıfır bir Ubuntu makinesinde Docker Engine ve Docker Compose v2 eklentisini kurun:

```bash
sudo apt-get update
sudo apt-get install -y ca-certificates curl docker.io docker-compose-plugin
sudo usermod -aG docker $USER
```

---

## Ana Yöntem: Adım Adım Manuel Kurulum

### Adım 1: Çalışma Dizinini Oluşturma

```bash
mkdir -p ~/novashop/infra/jenkins
cd ~/novashop/infra/jenkins
```

---

### Adım 2: Docker Compose Dosyasını Hazırlama

Jenkins LTS (JDK 17) imajını kullanan ve host Docker motoruna doğrudan erişebilen `docker-compose.yml` dosyasını oluşturun:

```bash
cat << 'COMPOSE_EOF' > docker-compose.yml
services:
  jenkins:
    image: jenkins/jenkins:lts-jdk17
    container_name: jenkins
    restart: always
    user: root # Docker soketine erişebilmek ve araç kurabilmek için
    ports:
      - "18080:8080"
      - "50000:50000"
    volumes:
      - jenkins_home:/var/jenkins_home
      - /var/run/docker.sock:/var/run/docker.sock # Host Docker daemon erişimi
      - /usr/bin/docker:/usr/bin/docker:ro

volumes:
  jenkins_home:
COMPOSE_EOF
```

---

### Adım 3: Jenkins Konteynerini Başlatma

```bash
docker compose up -d
```

Durumu kontrol edin:
```bash
docker ps --filter "name=jenkins"
```
*Beklenen çıktı:* `jenkins` konteyneri `Up` durumunda olmalıdır.

---

### Adım 4: İlk Yönetici (initialAdminPassword) Şifresini Alma

Jenkins ilk kurulum esnasında güvenlik amacıyla tek kullanımlık bir yönetici parolası üretir:

```bash
docker exec -it jenkins cat /var/jenkins_home/secrets/initialAdminPassword
```

---

### Adım 5: Web Arayüzüne Erişim ve Kurulum Sihirbazı

#### Model A: Doğrudan IP ile Erişim
```text
http://<UBUNTU_IP>:18080
```

#### Model B: Kurumsal DNS ve SSL ile Erişim
```text
https://student100-jenkins.devopsatolyesi.com
```

1. Açılan ekranda **Administrator password** alanına 4. adımda kopyaladığınız parolayı yapıştırın ve **Continue** butonuna basın.
2. **Install suggested plugins** seçeneğini tıklayarak standart Jenkins eklentilerinin kurulmasını bekleyin.
3. Eklenti kurulumu bittiğinde ilk yönetici kullanıcı bilgilerinizi (kullanıcı adı, şifre, e-posta) oluşturun.
4. **Save and Finish** butonuna basarak Jenkins paneline erişin.

---

### Adım 6: Docker İletişimini Doğrulama

Jenkins konteynerinin host Docker motoruyla sorunsuz konuştuğunu test edin:

```bash
docker exec -it jenkins docker version
```
*Beklenen çıktı:* Hem Client hem de Server (Host) Docker versiyon bilgisi hatasız görüntülenmelidir.

---

## Alternatif Yöntem: Hızlı Kurulum (Fast-Track)

Repo içindeki hazır yapılandırmayı tek komutla çalıştırmak için:

```bash
cd ~/novashop
docker compose -f infra/jenkins/docker-compose.yml up -d
```

---

## Servisi Durdurma ve Başlatma (RAM Tasarrufu)

Jenkins çalışırken ~800 MB - 1.2 GB RAM tüketir. İhtiyaç duymadığınız lablarda RAM'i boşa çıkarmak için:

```bash
# Servisi durdurun (Tüm işler, boru hatları ve eklentiler korunur):
cd ~/novashop/infra/jenkins && docker compose stop

# Tekrar ihtiyaç duyduğunuzda:
cd ~/novashop/infra/jenkins && docker compose start
```
