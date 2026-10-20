# Platform Hazırlık 05 — Nginx Reverse Proxy ve Wildcard SSL Yapılandırması

Ubuntu sunucusu üzerinde çalışan tüm DevOps araçlarını (`NovaShop UI`, `GitLab`, `Harbor`, `SonarQube`, `Jenkins`) standart HTTP/HTTPS (port 80 ve 443) üzerinden tek bir güvenli giriş noktasıyla dış dünyaya açmak için Nginx Edge Reverse Proxy kullanılır.

Bu mimari, **Cloudflare Full SSL** modu ile entegre çalışacak şekilde tasarlanmıştır. Böylece:
1. **Public Repoda Gizli Anahtar Olmaz:** SSL özel anahtarı (`origin.key`) repoda tutulmaz, sunucuda yerel olarak üretilir (sıfır güvenlik riski).
2. **Rate-Limit Yoktur:** Her servis veya kullanıcı ortamı için ayrı ayrı Let's Encrypt üretmek yerine tek bir `*.devopsatolyesi.com` Wildcard Origin sertifikası kullanılır.
3. **Doğrudan IP:Port Asla Bozulmaz:** Nginx 80/443 portlarını yönetirken, Docker konteynerleri kendi portlarında (`8888`, `8929`, `18082`, `19000`, `18080`) doğrudan açık kalmaya devam eder.

---

## Servis ve Port Eşleme Tablosu (Örnek: `student100`)

| Servis | Dahili Docker / Platform Portu | Kurumsal DNS + SSL (HTTPS) |
|---|:---:|---|
| **NovaShop UI** | `19001 / 8888` (NodePort `30080`) | `https://student100-novashop.devopsatolyesi.com` |
| **GitLab CE** | `18929 / 8929` | `https://student100-gitlab.devopsatolyesi.com` |
| **Harbor Registry** | `18444 / 18082` | `https://student100-harbor.devopsatolyesi.com` |
| **Argo CD** | `18082 / 8080` | `https://student100-argocd.devopsatolyesi.com` |
| **SonarQube** | `19000` | `https://student100-sonarqube.devopsatolyesi.com` |
| **Jenkins** | `18080` | `https://student100-jenkins.devopsatolyesi.com` |
| **Kibana (ELK)** | `15601 / 5601` | `https://student100-kibana.devopsatolyesi.com` |

---

## Yöntem A: Tek Komutla Aktivasyon (Önerilen)

Eğer bir kullanıcı kimliği (örneğin `student100` veya `student01`) ve DNS kaydı tahsis edildiyse, tüm SSL ve Nginx yapılandırmasını tek bir komutla ayağa kaldırabilirsiniz:

```bash
cd ~/novashop
sudo bash infra/nginx/setup-ssl-edge.sh student100
```

*Bu script arkada:*
1. Nginx ve OpenSSL araçlarını yükler.
2. `/etc/nginx/ssl/devops-training/` dizininde `*.devopsatolyesi.com` için yerel Wildcard Origin sertifikasını üretir.
3. Port 80 yönlendirmesini ve Port 443 SSL reverse proxy kurallarını Nginx'e bağlar.
4. Nginx sözdizimini test edip servisi yeniden başlatır.

---

## Yöntem B: Adım Adım Manuel Kurulum

Otomasyon scriptini kullanmak yerine tüm adımları kendiniz yapılandırmak isterseniz:

### Adım 1: Nginx ve OpenSSL Kurulumu

```bash
sudo apt update
sudo apt install -y nginx openssl
sudo systemctl enable --now nginx
```

---

### Adım 2: Wildcard Origin SSL Sertifikası Üretme

Sunucunuzda Cloudflare Full SSL modu ile uyumlu yerel wildcard sertifika oluşturun:

```bash
sudo mkdir -p /etc/nginx/ssl/devops-training

sudo openssl req -x509 -nodes -newkey rsa:2048 -days 3650 \
  -keyout /etc/nginx/ssl/devops-training/origin.key \
  -out /etc/nginx/ssl/devops-training/origin.crt \
  -subj "/CN=student100.devopsatolyesi.com" \
  -addext "subjectAltName=DNS:student100.devopsatolyesi.com,DNS:*.devopsatolyesi.com,DNS:devopsatolyesi.com"

sudo chmod 0600 /etc/nginx/ssl/devops-training/origin.key
```

---

### Adım 3: Nginx Konfigürasyonunu Tanımlama

Aşağıdaki yapılandırmayı `/etc/nginx/sites-available/student-tools.conf` olarak kaydedin (`student100` yerine kendi kullanıcı kimliğinizi yazabilirsiniz):

```bash
STUDENT_ID="student100"
DOMAIN_NAME="devopsatolyesi.com"

cat << NGINX_EOF | sudo tee /etc/nginx/sites-available/student-tools.conf
# HTTP -> HTTPS Yönlendirmesi
server {
    listen 80;
    server_name ${STUDENT_ID}-*.${DOMAIN_NAME};
    return 301 https://\$host\$request_uri;
}

# NovaShop UI -> Port 8888
server {
    listen 443 ssl http2;
    server_name ${STUDENT_ID}-novashop.${DOMAIN_NAME};
    ssl_certificate /etc/nginx/ssl/devops-training/origin.crt;
    ssl_certificate_key /etc/nginx/ssl/devops-training/origin.key;
    location / {
        proxy_pass http://127.0.0.1:8888;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
    }
}

# GitLab CE -> Port 8929
server {
    listen 443 ssl http2;
    server_name ${STUDENT_ID}-gitlab.${DOMAIN_NAME};
    ssl_certificate /etc/nginx/ssl/devops-training/origin.crt;
    ssl_certificate_key /etc/nginx/ssl/devops-training/origin.key;
    client_max_body_size 250M;
    location / {
        proxy_pass http://127.0.0.1:8929;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
    }
}

# Harbor Registry -> Port 18082
server {
    listen 443 ssl http2;
    server_name ${STUDENT_ID}-harbor.${DOMAIN_NAME};
    ssl_certificate /etc/nginx/ssl/devops-training/origin.crt;
    ssl_certificate_key /etc/nginx/ssl/devops-training/origin.key;
    client_max_body_size 0;
    location / {
        proxy_pass http://127.0.0.1:18082;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
        proxy_buffering off;
        proxy_request_buffering off;
    }
}

# SonarQube -> Port 19000
server {
    listen 443 ssl http2;
    server_name ${STUDENT_ID}-sonarqube.${DOMAIN_NAME};
    ssl_certificate /etc/nginx/ssl/devops-training/origin.crt;
    ssl_certificate_key /etc/nginx/ssl/devops-training/origin.key;
    location / {
        proxy_pass http://127.0.0.1:19000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
    }
}

# Jenkins -> Port 18080 (WebSocket Destekli)
server {
    listen 443 ssl http2;
    server_name ${STUDENT_ID}-jenkins.${DOMAIN_NAME};
    ssl_certificate /etc/nginx/ssl/devops-training/origin.crt;
    ssl_certificate_key /etc/nginx/ssl/devops-training/origin.key;
    client_max_body_size 256M;
    location / {
        proxy_pass http://127.0.0.1:18080;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
NGINX_EOF
```

---

### Adım 4: Yapılandırmayı Etkinleştirme ve Test

```bash
# 1. Varsayılan Nginx sayfasını kaldırın ve linki bağlayın
sudo rm -f /etc/nginx/sites-enabled/default
sudo ln -sf /etc/nginx/sites-available/student-tools.conf /etc/nginx/sites-enabled/

# 2. Sözdizimini test edin
sudo nginx -t

# 3. Nginx servisini yeniden yükleyin
sudo systemctl reload nginx
```

---

## Doğrulama ve Sağlık Testi (`student100`)

Servislerin HTTPS üzerinden çalıştığını test edin:

```bash
# Web UI testi:
curl -kI https://student100-novashop.devopsatolyesi.com

# Harbor HTTPS testi:
curl -kI https://student100-harbor.devopsatolyesi.com

# Jenkins HTTPS testi:
curl -kI https://student100-jenkins.devopsatolyesi.com
```

*Açıklama:* Tarayıcı üzerinden Cloudflare aracılığıyla bağlanıldığında Cloudflare'in geçerli genel SSL sertifikası doğrulanır. `curl -k` ise sunucu içerisinden yerel origin sertifikasını doğrulamadan hızlıca test etmek içindir.
