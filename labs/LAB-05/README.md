# LAB-05-GITHUB-ACTIONS — GitHub Actions, Docker Hub ve Otomatik EC2 Dağıtımı

| Seviye | Profil / Araçlar | Açık Portlar |
|---|---|---|
| Orta | GitHub Actions, Docker Hub, AWS EC2, Docker Compose | 22 (SSH), 80 (HTTP), 19001 / 8888 (Storefront UI) |

---

### Amaç

Bu laboratuvarda, karmaşık AWS ECR ve IAM OIDC süreçleri yerine modern endüstri standardı olan **Docker Hub** ve **GitHub Actions** kullanarak uçtan uca tam otomatik bir CI/CD altyapısı kuracaksınız.

Süreç iki temel iş akışından (workflow) oluşur:
1. **Altyapı İş Akışı (`01-infra-ec2.yml`):** GitHub Actions üzerinden tek tıkla AWS üzerinde bir EC2 Ubuntu sunucusu oluşturur ve sunucuya otomatik olarak **Docker Engine** ile **Docker Compose** eklentilerini kurar.
2. **Dağıtım İş Akışı (`02-deploy.yml`):** Koda yapılan her commit'te NovaShop UI servisini test eder, imajı derleyip **Docker Hub** kayıt defterine gönderir, ardından EC2 sunucusuna SSH ile bağlanarak Docker Compose ile yeni sürümü devreye alır ve sağlık kontrolünü doğrular.

---

### Kazanımlar

- AWS konsoluna elle girmeden GitHub Actions ile EC2 sunucusunu Docker ve Compose kurulu şekilde otomatik ayağa kaldırmak.
- Docker Hub üzerinde erişim belirteci (Personal Access Token) oluşturup GitHub Actions ile entegre etmek.
- Java 21 Spring Boot mikroservisini derlemek, birim testlerini (`mvnw test`) koşmak ve Docker imajı olarak Docker Hub'a push etmek.
- EC2 sunucusuna SSH üzerinden güvenli bağlanıp Docker Compose ile sıfır kesintiye yakın dağıtım gerçekleştirmek.
- Konteyner sağlık durumunu (`/actuator/health`) otomatik test edip olası hatalarda sistemi koruyan rollback mekanizmasını uygulamak.

---

### Ön koşullar

> [!NOTE]
> Bu laboratuvar AWS Cloud ortamı kullanır. Yerel Kind veya Docker platformlarımız maliyetsiz çalışırken, bu lab için geçerli bir AWS hesabı ve IAM erişim yetkisi gerekmektedir.

1. **GitHub Hesabı ve Reposu:** Kendi GitHub hesabınız altında forkladığınız veya klonladığınız `novashop` reposu.
2. **Docker Hub Hesabı:** [hub.docker.com](https://hub.docker.com/) üzerinde ücretsiz bir hesap.
3. **AWS Hesabı:** EC2 ve Security Group oluşturma yetkisine sahip bir IAM kullanıcısı (Access Key & Secret Key).

---

### Mimari ve Çalışma Modeli

```mermaid
flowchart TD
    subgraph GitHub Actions Pipeline
        direction TB
        W1[01 - Infra Workflow<br/>Manuel Tetikleme] -->|AWS CLI + user_data| EC2_NEW[(AWS EC2 Sunucusu<br/>Docker & Compose Kurulu)]
        
        Commit([Git Push / Commit]) --> W2[02 - Deploy Pipeline]
        W2 -->|1. Test & Build| MVN[Maven Test - Java 21]
        MVN -->|2. Docker Push| DH[(Docker Hub Registry<br/>username/novashop-ui:SHA)]
        DH -->|3. SSH Deploy| EC2_NEW
    end

    subgraph AWS Cloud
        EC2_NEW -->|docker pull| DH
        EC2_NEW -->|docker compose up -d| APP[NovaShop UI :8888<br/>+ Catalog :8080]
    end

    Tester([Geliştirici / Test Tarayıcısı]) -->|HTTP :8888/actuator/health| EC2_NEW
```

---

### GitHub Secrets ve Variables Tanımlama

GitHub reponuzda **Settings > Secrets and variables > Actions** sayfasına gidin.

#### 1. Repository Secrets (Gizli Değerler)
`New repository secret` butonuna tıklayarak aşağıdaki **4 gizli anahtarı** ekleyin:

| Secret Adı | Nereden Alınır? / Değer | Açıklama |
|---|---|---|
| `DOCKERHUB_USERNAME` | Docker Hub kullanıcı adınız (örn: `johndoe`) | İmajların yükleneceği Docker Hub hesabı |
| `DOCKERHUB_TOKEN` | Docker Hub > **Account Settings > Security > New Access Token** | Docker Hub için Read/Write yetkili token (`dckr_pat_...`) |
| `AWS_ACCESS_KEY_ID` | AWS IAM konsolundan alınan erişim anahtarı | EC2 sunucusunu otomatik oluşturmak için |
| `AWS_SECRET_ACCESS_KEY` | AWS IAM konsolundan alınan gizli anahtar | EC2 sunucusunu otomatik oluşturmak için |

> [!NOTE]
> `EC2_SSH_KEY` secret'ı, 1. Adımdaki altyapı iş akışı çalıştırıldıktan sonra üretilen anahtarla eklenecektir.

#### 2. Repository Variables (Genel Değişkenler)
Aynı sayfada **Variables** sekmesine geçin ve `New repository variable` butonu ile ekleyin:

| Variable Adı | Varsayılan Değer | Açıklama |
|---|---|---|
| `AWS_REGION` | `us-east-1` | Sunucunun kurulacağı AWS bölgesi (N. Virginia) |
| `EC2_USER` | `ubuntu` | EC2 SSH kullanıcı adı |

---

### Adım Adım Uygulama Rehberi

#### 1. EC2 Altyapısını GitHub Actions ile Otomatik Kurma

Sunucuyu AWS konsolunda elle kurmak yerine depoda hazır bulunan **`01 - AWS EC2 Altyapı Kurulumu (Infra Provisioning)`** iş akışını çalıştırın:

1. GitHub reponuzda **Actions** sekmesine tıklayın.
2. Sol menüden **`01 - AWS EC2 Altyapı Kurulumu (Infra Provisioning)`** iş akışını seçin.
3. Sağ üstteki **Run workflow** butonuna tıklayın:
   - **EC2 Instance Tipi:** `t3.small` (veya `t3.micro`)
   - **AWS Bölgesi:** `us-east-1` (N. Virginia)
4. **Run workflow** butonuna basarak iş akışını başlatın.

**İş Akışı Arka Planda Neler Yapar?**
- `novashop-web-sg` adında güvenlik grubu oluşturup **22 (SSH)**, **80 (HTTP)**, **443 (HTTPS)** ve **8888 (UI)** portlarını açar.
- `novashop-key` adında bir SSH Key Pair oluşturur.
- Ubuntu 22.04 LTS sunucusunu başlatır; `user_data` betiği ile sunucu açılırken **Docker Engine**, **Docker Compose Plugin**, **git** ve **curl** paketlerini otomatik kurar.
- Sunucu hazır olduğunda `Public IP` adresini ekrana yazdırır ve SSH anahtarını artifact olarak sunar.

---

#### 2. Sunucu IP ve SSH Anahtarını GitHub'a Tanımlama

1. Çalışan iş akışının özet sayfasına (**Summary**) gidin.
2. Sayfanın en altındaki **Dağıtım Özeti** tablosunda sunucunuzun `Public IP` adresini göreceksiniz.
3. Sayfadaki **Artifacts** bölümünden `novashop-ec2-private-key` dosyasını indirin ve metin editörüyle açın.
4. GitHub **Settings > Secrets and variables > Actions** sayfasına dönün:
   - **Variables** sekmesine gidin: `EC2_HOST` adında yeni değişken ekleyin ve değer olarak sunucunun `Public IP` adresini yazın.
   - **Secrets** sekmesine gidin: `EC2_SSH_KEY` adında yeni secret ekleyin ve indirdiğiniz `novashop-key.pem` dosyasının tam metin içeriğini yapıştırın.

Artık ortamınız dağıtıma %100 hazırdır!

---

#### 3. Dağıtım Pipeline'ını Çalıştırma (CI/CD Deploy)

NovaShop UI mikroservisini derleyip EC2'ye otomatik dağıtmak için:

1. GitHub reponuzda **Actions** sekmesine gidin.
2. **`02 - NovaShop CI/CD Pipeline (Docker Hub & EC2 Deploy)`** iş akışını seçin.
3. **Run workflow** butonuna tıklayarak doğrudan tetikleyin (veya `src/ui/` altında kod değişikliği yaparak commit atın).

**Pipeline Adımları:**
1. **Build & Push:**
   - Java 21 ile birim testleri koşar (`./mvnw test`).
   - Docker Hub'da oturum açar.
   - İmajı `${DOCKERHUB_USERNAME}/novashop-ui:<COMMIT_SHA>` ve `latest` etiketleriyle derleyip Docker Hub'a yükler.
2. **Deploy to EC2:**
   - Appleboy SSH action ile EC2 sunucusuna bağlanır.
   - Yeni imajı Docker Hub'dan çeker (`docker pull`).
   - `docker compose -f docker-compose.prod.yml up -d` ile servisi başlatır.
   - 15 denemede konteyner içi `/actuator/health` kontrolü yapar.
   - Runner makineden dışarıdan `http://${EC2_HOST}:8888/actuator/health` adresine canlı test isteği atarak dağıtımı doğrular.

---

### Doğal Doğrulama ve Beklenen Sonuç

Yerel terminalinizden veya tarayıcınızdan canlı dağıtımı test edin:

```bash
# 1. Spring Boot Actuator Sağlık Kontrolü
curl -s "http://${EC2_HOST}:8888/actuator/health"
```
*Beklenen çıktı:*
```json
{"status":"UP"}
```

```bash
# 2. UI Mağaza Ön Yüzü Kontrolü
curl -s -I "http://${EC2_HOST}:8888/"
```
*Beklenen çıktı:*
```text
HTTP/1.1 200 OK
Content-Type: text/html;charset=UTF-8
```

Tarayıcınızda `http://<EC2_HOST>:8888/` adresini açtığınızda NovaShop vitrin sayfasının canlı çalıştığını görebilirsiniz.

---

### Kontrollü Sürüm Güncelleme ve Otomatik Rollback Testi

Sistemin dağıtım hatasında otomatik olarak önceki stabil sürüme döndüğünü test etmek için EC2 sunucusunda kasıtlı olarak hatalı bir imaj dağıtımını simüle edin:

```bash
# EC2 sunucunuza bağlanın
ssh -i ~/.ssh/novashop-key.pem ubuntu@<EC2_HOST>
cd ~/novashop-deploy

# Kasıtlı olarak /actuator/health vermeyen hatalı bir imaj ile deploy tetikleyin:
./deploy.sh "alpine:latest"
```

*Beklenen çıktı:*
```text
=== 1. Mevcut Stabil İmajı Tespit Etme ===
Mevcut stabil imaj: johndoe/novashop-ui:1a2b3c4
=== 2. Yeni İmajı Docker Hub'dan Çekme ===
...
=== 5. Sağlık Kontrolü (Smoke Test) ===
   Servis bekleniyor (1/15)...
   ...
❌ HATA: Sağlık kontrolü başarısız oldu! Otomatik Rollback başlatılıyor...
Önceki stabil sürüme dönülüyor: johndoe/novashop-ui:1a2b3c4
✅ Rollback tamamlandı: Stabil imaj yeniden devrede.
```

Sistemin çökmediğini ve önceki sürümün yayında kaldığını teyit edin:
```bash
curl -s http://127.0.0.1:8888/actuator/health
```
*Beklenen çıktı:* `{"status":"UP"}`

---

### Troubleshooting

#### Senaryo 1: Docker Hub Push Sırasında `unauthorized: incorrect username or password`
- **Belirti:** `docker/login-action` adımında oturum açma hatası.
- **Çözüm:** GitHub Secrets altındaki `DOCKERHUB_USERNAME` ve `DOCKERHUB_TOKEN` değerlerini kontrol edin. Token oluştururken `Access permissions` ayarının `Read & Write` olduğundan emin olun.

#### Senaryo 2: SSH Deploy Adımında `Host key verification failed` veya Timeout
- **Belirti:** `appleboy/ssh-action` adımında sunucuya bağlanamama.
- **Çözüm:** 
  1. `EC2_HOST` değişkeninin doğru Public IP olduğunu kontrol edin.
  2. `EC2_SSH_KEY` secret'ının başında `-----BEGIN RSA PRIVATE KEY-----` ve sonunda `-----END RSA PRIVATE KEY-----` satırlarının tam olduğunu teyit edin.
  3. Güvenlik grubunda Port 22'nin açık olduğunu doğrulayın.

#### Senaryo 3: EC2'de Docker İzni Hatası (`permission denied while trying to connect to the Docker daemon`)
- **Belirti:** `docker pull` veya `docker compose` komutunda yetki hatası.
- **Çözüm:** User data betiği `ubuntu` kullanıcısını `docker` grubuna ekler. Eğer oturum yenilenmediyse EC2 üzerinde `newgrp docker` veya `sudo usermod -aG docker ubuntu` çalıştırın.

---

### Cleanup

Laboratuvar tamamlandığında AWS üzerindeki kaynakları temizlemek için yerel terminalinizden veya CloudShell'den çalıştırın:

```bash
# 1. EC2 Instance'ını Sonlandırın
INSTANCE_ID=$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=novashop-docker-host" "Name=instance-state-name,Values=running" \
  --query "Reservations[0].Instances[0].InstanceId" --output text)

if [ "$INSTANCE_ID" != "None" ] && [ -n "$INSTANCE_ID" ]; then
  aws ec2 terminate-instances --instance-ids "$INSTANCE_ID"
  aws ec2 wait instance-terminated --instance-ids "$INSTANCE_ID"
fi

# 2. Güvenlik Grubunu ve Anahtarı Silin
aws ec2 delete-security-group --group-name novashop-web-sg 2>/dev/null || true
aws ec2 delete-key-pair --key-name novashop-key 2>/dev/null || true
```
