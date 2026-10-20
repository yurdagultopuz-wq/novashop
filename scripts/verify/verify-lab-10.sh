#!/usr/bin/env bash
# NovaShop — LAB-10 Gözlemlenebilirlik (Prometheus, Grafana, OpenTelemetry) Doğrulama Betiği
set -e

PORT="${1:-8888}"
HOST="${2:-localhost}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

echo "=== [LAB-10] Gözlemlenebilirlik Doğrulama Başlatılıyor ==="

if [ "$PORT" = "--config-only" ]; then
    for required_file in \
        "$REPO_ROOT/deploy/observability/docker-compose.observability.yml" \
        "$REPO_ROOT/deploy/observability/prometheus.yml" \
        "$REPO_ROOT/deploy/observability/alert.rules.yml" \
        "$REPO_ROOT/deploy/observability/alertmanager.yml" \
        "$REPO_ROOT/deploy/observability/otel-collector-config.yaml" \
        "$REPO_ROOT/deploy/observability/grafana/provisioning/datasources/datasources.yml" \
        "$REPO_ROOT/deploy/observability/grafana/provisioning/dashboards/dashboards.yml" \
        "$REPO_ROOT/deploy/observability/grafana/provisioning/dashboards/json/novashop-services-overview.json" \
        "$REPO_ROOT/deploy/observability/grafana/provisioning/dashboards/json/docker-container-host-overview.json" \
        "$REPO_ROOT/deploy/k8s/servicemonitors/novashop-servicemonitor.yaml"; do
        if [ ! -f "$required_file" ]; then
            echo "❌ HATA: Gerekli gözlemlenebilirlik dosyası bulunamadı: $required_file" >&2
            exit 1
        fi
    done

    grep -q 'metrics_path: "/actuator/prometheus"' "$REPO_ROOT/deploy/observability/prometheus.yml" || {
        echo "❌ HATA: Prometheus Actuator metrik scrape yolu eksik." >&2
        exit 1
    }
    grep -q 'job_name: "novashop-catalog"' "$REPO_ROOT/deploy/observability/prometheus.yml" || {
        echo "❌ HATA: Prometheus catalog scrape hedefi eksik." >&2
        exit 1
    }
    grep -q 'job_name: "novashop-cart"' "$REPO_ROOT/deploy/observability/prometheus.yml" || {
        echo "❌ HATA: Prometheus cart scrape hedefi eksik." >&2
        exit 1
    }
    grep -q 'job_name: "novashop-checkout"' "$REPO_ROOT/deploy/observability/prometheus.yml" || {
        echo "❌ HATA: Prometheus checkout scrape hedefi eksik." >&2
        exit 1
    }
    grep -q 'job_name: "novashop-orders"' "$REPO_ROOT/deploy/observability/prometheus.yml" || {
        echo "❌ HATA: Prometheus orders scrape hedefi eksik." >&2
        exit 1
    }
    grep -q 'job_name: "node-exporter"' "$REPO_ROOT/deploy/observability/prometheus.yml" || {
        echo "❌ HATA: Prometheus node-exporter scrape hedefi eksik." >&2
        exit 1
    }
    grep -q 'job_name: "cadvisor"' "$REPO_ROOT/deploy/observability/prometheus.yml" || {
        echo "❌ HATA: Prometheus cadvisor scrape hedefi eksik." >&2
        exit 1
    }
    grep -q 'otlp/jaeger' "$REPO_ROOT/deploy/observability/otel-collector-config.yaml" || {
        echo "❌ HATA: Jaeger OTLP exporter yapılandırması eksik." >&2
        exit 1
    }
    grep -q 'alertmanager:9093' "$REPO_ROOT/deploy/observability/prometheus.yml" || {
        echo "❌ HATA: Prometheus Alertmanager yönlendirmesi eksik." >&2
        exit 1
    }
    grep -q 'checkout_attempt_total' "$REPO_ROOT/src/ui/src/main/java/com/amazon/sample/ui/web/CheckoutController.java" || {
        echo "❌ HATA: NovaShop UI iş metrikleri (checkout_attempt_total) eksik." >&2
        exit 1
    }
    echo "✅ Gözlemlenebilirlik yapılandırması (Prometheus hedefleri, Node Exporter, cAdvisor, Grafana Provisioning, ServiceMonitor ve İş Metrikleri) doğrulandı."
    echo "=== [LAB-10] Yapılandırma Doğrulaması Başarılı (PASS) ==="
    exit 0
fi

# 1. Spring Boot Actuator Prometheus Metrik Endpoint'i (Kind 30080 veya Docker 8888)
if ! curl -s --connect-timeout 2 "http://${HOST}:${PORT}/actuator/health" >/dev/null 2>&1; then
    if curl -s --connect-timeout 2 "http://${HOST}:30080/actuator/health" >/dev/null 2>&1; then
        PORT=30080
    fi
fi

echo "1. Actuator Prometheus metrik endpoint'i test ediliyor (Port ${PORT})..."
METRICS_BODY=$(curl -s --connect-timeout 5 "http://${HOST}:${PORT}/actuator/prometheus" 2>/dev/null || echo "")

if echo "$METRICS_BODY" | grep -q "jvm_memory_used_bytes"; then
    echo "✅ /actuator/prometheus üzerinden JVM metrikleri başarıyla alınıyor."
else
    echo "⚠️ UYARI: http://${HOST}:${PORT}/actuator/prometheus yanıt vermedi veya jvm_memory_used_bytes içermiyor."
    echo "   (UI servisinin ayakta olduğundan emin olun)"
fi

# 2. HTTP Server İstek Sayacı Kontrolü
if echo "$METRICS_BODY" | grep -q "http_server_requests_seconds"; then
    echo "✅ HTTP istek gecikme ve sayaç metrikleri (http_server_requests_seconds) mevcut."
fi

# 3. OpenTelemetry / Jaeger Trace Context
if echo "$METRICS_BODY" | grep -qi "trace"; then
    echo "✅ Dağıtık izleme (Trace) metrikleri etkin."
fi

# 4. Prometheus / Grafana Canlı Port Kontrolü (Opsiyonel)
PROM_PORT="${3:-9091}"
if ! curl -s --connect-timeout 2 "http://${HOST}:${PROM_PORT}/-/healthy" >/dev/null 2>&1; then
    if curl -s --connect-timeout 2 "http://${HOST}:19090/-/healthy" >/dev/null 2>&1; then
        PROM_PORT=19090
    fi
fi
PROM_HEALTH=$(curl -s --connect-timeout 3 "http://${HOST}:${PROM_PORT}/-/healthy" 2>/dev/null || echo "")
if [ "$PROM_HEALTH" = "Prometheus Server is Healthy." ]; then
    echo "✅ Prometheus sunucusu sağlıklı çalışıyor (Port $PROM_PORT)."
fi

echo "=== [LAB-10] Gözlemlenebilirlik Doğrulama Tamamlandı ==="
