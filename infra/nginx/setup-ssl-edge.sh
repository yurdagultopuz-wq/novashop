#!/usr/bin/env bash
# ==============================================================================
# NovaShop — Nginx Edge & Wildcard Origin SSL Aktivasyon Betiği
# ==============================================================================
set -euo pipefail

STUDENT_ID="${1:-}"
DOMAIN_NAME="${2:-devopsatolyesi.com}"

if [[ -z "${STUDENT_ID}" ]]; then
    read -rp "Öğrenci Kodunuzu Girin (Örn: student100 veya student01): " STUDENT_ID
fi

if [[ -z "${STUDENT_ID}" ]]; then
    echo "❌ HATA: Öğrenci kodu boş bırakılamaz!"
    exit 1
fi

echo "===> [1/4] Nginx Kurulumu Kontrol Ediliyor..."
if ! command -v nginx &>/dev/null; then
    sudo apt-get update -y
    sudo apt-get install -y nginx openssl
fi

echo "===> [2/4] Wildcard Origin SSL Sertifikası Üretiliyor (*.${DOMAIN_NAME})..."
SSL_DIR="/etc/nginx/ssl/devops-training"
sudo mkdir -p "${SSL_DIR}"

if [[ ! -f "${SSL_DIR}/origin.crt" || ! -f "${SSL_DIR}/origin.key" ]]; then
    sudo openssl req -x509 -nodes -newkey rsa:2048 -days 3650 \
      -keyout "${SSL_DIR}/origin.key" \
      -out "${SSL_DIR}/origin.crt" \
      -subj "/CN=${STUDENT_ID}.${DOMAIN_NAME}" \
      -addext "subjectAltName=DNS:${STUDENT_ID}.${DOMAIN_NAME},DNS:*.${DOMAIN_NAME},DNS:${DOMAIN_NAME}" >/dev/null 2>&1
    sudo chmod 0600 "${SSL_DIR}/origin.key"
    echo "✅ SSL sertifikası başarıyla oluşturuldu: ${SSL_DIR}/origin.crt"
else
    echo "ℹ️ Mevcut SSL sertifikası korundu."
fi

echo "===> [3/4] Nginx Reverse Proxy Konfigürasyonu Uygulanıyor..."
CONF_PATH="/etc/nginx/sites-available/student-tools.conf"

sudo tee "${CONF_PATH}" > /dev/null << NGINX_CONF
# ==============================================================================
# NovaShop DevOps Platform — Nginx Edge Reverse Proxy (${STUDENT_ID})
# ==============================================================================

# HTTP -> HTTPS Yönlendirmesi (Port 80 -> 443)
server {
    listen 80;
    server_name ~^${STUDENT_ID}-.*\\.${DOMAIN_NAME}\$ ~^ecommerce-.*\\.${DOMAIN_NAME}\$ ${DOMAIN_NAME};
    return 301 https://\$host\$request_uri;
}

# Varsayılan SSL Sunucu (Tanımsız domainlerin NovaShop'a karışmasını önler)
server {
    listen 443 ssl default_server;
    server_name _;

    ssl_certificate ${SSL_DIR}/origin.crt;
    ssl_certificate_key ${SSL_DIR}/origin.key;
    ssl_protocols TLSv1.2 TLSv1.3;

    location / {
        default_type text/plain;
        return 404 "NovaShop DevOps Platform: Tanimlanmamis servis veya alan adi.\n";
    }
}

# 0. Cockpit Web Terminal -> Port 9090 (HTTPS)
server {
    listen 443 ssl;
    server_name ${STUDENT_ID}-cockpit.${DOMAIN_NAME} ecommerce-cockpit.${DOMAIN_NAME};

    ssl_certificate ${SSL_DIR}/origin.crt;
    ssl_certificate_key ${SSL_DIR}/origin.key;
    ssl_protocols TLSv1.2 TLSv1.3;

    location / {
        proxy_pass https://127.0.0.1:9090;
        proxy_ssl_verify off;
        proxy_buffering off;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection \$connection_upgrade;
    }
}

# 1. NovaShop Web UI -> Port 8888
server {
    listen 443 ssl;
    server_name ${STUDENT_ID}-novashop.${DOMAIN_NAME} novashop.${DOMAIN_NAME};

    ssl_certificate ${SSL_DIR}/origin.crt;
    ssl_certificate_key ${SSL_DIR}/origin.key;
    ssl_protocols TLSv1.2 TLSv1.3;

    location / {
        proxy_pass http://127.0.0.1:8888;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
    }
}

# 2. GitLab CE -> Port 8929
server {
    listen 443 ssl;
    server_name ${STUDENT_ID}-gitlab.${DOMAIN_NAME};

    ssl_certificate ${SSL_DIR}/origin.crt;
    ssl_certificate_key ${SSL_DIR}/origin.key;
    ssl_protocols TLSv1.2 TLSv1.3;
    client_max_body_size 250M;

    location / {
        proxy_pass http://127.0.0.1:8929;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
    }
}

# 3. Harbor OCI Registry -> Port 18082
server {
    listen 443 ssl;
    server_name ${STUDENT_ID}-harbor.${DOMAIN_NAME};

    ssl_certificate ${SSL_DIR}/origin.crt;
    ssl_certificate_key ${SSL_DIR}/origin.key;
    ssl_protocols TLSv1.2 TLSv1.3;
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

# 4. SonarQube -> Port 19000
server {
    listen 443 ssl;
    server_name ${STUDENT_ID}-sonarqube.${DOMAIN_NAME};

    ssl_certificate ${SSL_DIR}/origin.crt;
    ssl_certificate_key ${SSL_DIR}/origin.key;
    ssl_protocols TLSv1.2 TLSv1.3;

    location / {
        proxy_pass http://127.0.0.1:19000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
    }
}

# 5. Jenkins Controller -> Port 18080 (WebSocket Destekli)
server {
    listen 443 ssl;
    server_name ${STUDENT_ID}-jenkins.${DOMAIN_NAME};

    ssl_certificate ${SSL_DIR}/origin.crt;
    ssl_certificate_key ${SSL_DIR}/origin.key;
    ssl_protocols TLSv1.2 TLSv1.3;
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

# 2. NovaShop Kubernetes UI (Kind K8s - LAB-06) -> Port 30080
server {
    listen 443 ssl;
    server_name ${STUDENT_ID}-k8s.${DOMAIN_NAME} ${STUDENT_ID}-kind.${DOMAIN_NAME} ${STUDENT_ID}-app1.${DOMAIN_NAME} ${STUDENT_ID}-k8s-app1.${DOMAIN_NAME} ecommerce-kind.${DOMAIN_NAME};

    ssl_certificate ${SSL_DIR}/origin.crt;
    ssl_certificate_key ${SSL_DIR}/origin.key;
    ssl_protocols TLSv1.2 TLSv1.3;

    location / {
        proxy_pass http://127.0.0.1:30080;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
    }
}

# 7. Prometheus (LAB-10) -> Port 9090
server {
    listen 443 ssl;
    server_name ${STUDENT_ID}-prometheus.${DOMAIN_NAME};

    ssl_certificate ${SSL_DIR}/origin.crt;
    ssl_certificate_key ${SSL_DIR}/origin.key;
    ssl_protocols TLSv1.2 TLSv1.3;

    location / {
        proxy_pass http://127.0.0.1:9091;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
    }
}

# 8. Grafana (LAB-10) -> Port 3000
server {
    listen 443 ssl;
    server_name ${STUDENT_ID}-grafana.${DOMAIN_NAME};

    ssl_certificate ${SSL_DIR}/origin.crt;
    ssl_certificate_key ${SSL_DIR}/origin.key;
    ssl_protocols TLSv1.2 TLSv1.3;

    location / {
        proxy_pass http://127.0.0.1:3000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}

# 9. Jaeger Tracing (LAB-10) -> Port 16686
server {
    listen 443 ssl;
    server_name ${STUDENT_ID}-jaeger.${DOMAIN_NAME};

    ssl_certificate ${SSL_DIR}/origin.crt;
    ssl_certificate_key ${SSL_DIR}/origin.key;
    ssl_protocols TLSv1.2 TLSv1.3;

    location / {
        proxy_pass http://127.0.0.1:16686;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
    }
}

# 10. Kibana Log Analitiği (LAB-11) -> Port 5601
server {
    listen 443 ssl;
    server_name ${STUDENT_ID}-kibana.${DOMAIN_NAME};

    ssl_certificate ${SSL_DIR}/origin.crt;
    ssl_certificate_key ${SSL_DIR}/origin.key;
    ssl_protocols TLSv1.2 TLSv1.3;

    location / {
        proxy_pass http://127.0.0.1:5601;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}

# 11. Elasticsearch API (LAB-11) -> Port 9200
server {
    listen 443 ssl;
    server_name ${STUDENT_ID}-elastic.${DOMAIN_NAME};

    ssl_certificate ${SSL_DIR}/origin.crt;
    ssl_certificate_key ${SSL_DIR}/origin.key;
    ssl_protocols TLSv1.2 TLSv1.3;

    location / {
        proxy_pass http://127.0.0.1:9200;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
    }
}
NGINX_CONF

# Sembolik linki oluştur ve default siteyi temizle
sudo rm -f /etc/nginx/sites-enabled/default
sudo ln -sf "${CONF_PATH}" /etc/nginx/sites-enabled/

echo "===> [4/4] Nginx Yapılandırması Test Ediliyor ve Yeniden Başlatılıyor..."
sudo nginx -t
sudo systemctl reload nginx

echo ""
echo "======================================================================"
echo "🎉 [${STUDENT_ID}] İçin DNS & Wildcard SSL Proxy Başarıyla Devreye Alındı!"
echo "======================================================================"
echo "🌐 NovaShop UI : https://${STUDENT_ID}-novashop.${DOMAIN_NAME}"
echo "🦊 GitLab CE   : https://${STUDENT_ID}-gitlab.${DOMAIN_NAME}"
echo "⚓ Harbor Reg  : https://${STUDENT_ID}-harbor.${DOMAIN_NAME}"
echo "📊 SonarQube   : https://${STUDENT_ID}-sonarqube.${DOMAIN_NAME}"
echo "👨‍✈️ Jenkins     : https://${STUDENT_ID}-jenkins.${DOMAIN_NAME}"
echo ""
echo "ℹ️ Hatırlatma:"
echo "Docker servisleriniz kendi portlarında (8888, 8929, 18082, 19000, 18080)"
echo "açık kalmaya devam eder. Dilediğiniz an http://<IP>:<PORT> ile de erişebilirsiniz."
echo "======================================================================"
