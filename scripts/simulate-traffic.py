#!/usr/bin/env python3
"""
==============================================================================
NovaShop — Çok Yönlü Trafik, Log ve Trace Simülatörü (Observability Generator)
Kapsam:
  1. NovaShop UI & API HTTP İstekleri (Prometheus RED & Business Metrikleri)
  2. Elasticsearch Yapılandırılmış Log Enjeksiyonu (Kibana Discover & Dashboards)
  3. OpenTelemetry / Jaeger Dağıtık İzleme (Tracing Waterfall & Latency)
==============================================================================
"""

import argparse
import datetime
import json
import random
import sys
import time
import uuid
import requests

def get_iso_timestamp():
    return datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%S.%f")[:-3] + "Z"

def get_today_index_suffix():
    return datetime.datetime.now(datetime.timezone.utc).strftime("%Y.%m.%d")

def hex_id(n_bytes):
    return uuid.uuid4().hex[:n_bytes * 2]

# ------------------------------------------------------------------------------
# 1. HTTP TRAFİK SİMÜLASYONU (Prometheus & Grafana)
# ------------------------------------------------------------------------------
def simulate_http_traffic(ui_url, count, inject_errors=False):
    print(f"\n🌐 [1/3] NovaShop Web & API HTTP İstekleri Gönderiliyor ({ui_url})...")
    session = requests.Session()
    success = 0
    errors = 0

    endpoints = [
        ("GET", "/", 40),
        ("GET", "/catalogue", 25),
        ("GET", "/cart", 15),
        ("GET", "/checkout", 15),
    ]

    for i in range(count):
        if inject_errors and random.random() < 0.4:
            # Yapay 404 / 500 hata üretici
            url = f"{ui_url}/api/invalid-payment-endpoint/{random.randint(100, 999)}"
            try:
                r = session.get(url, timeout=2)
                errors += 1
            except Exception:
                errors += 1
            continue

        r_val = random.randint(1, 100)
        curr = 0
        method, path = "GET", "/"
        for m, p, weight in endpoints:
            curr += weight
            if r_val <= curr:
                method, path = m, p
                break

        url = f"{ui_url}{path}"
        try:
            r = session.get(url, timeout=3)
            if r.status_code < 400:
                success += 1
            else:
                errors += 1
        except Exception as e:
            errors += 1

        if (i + 1) % 10 == 0 or (i + 1) == count:
            print(f"    -> {i + 1}/{count} HTTP isteği tamamlandı (Başarılı: {success}, Hata: {errors})")
        time.sleep(0.05)

# ------------------------------------------------------------------------------
# 2. ELASTICSEARCH LOG ENJEKSİYONU (Kibana)
# ------------------------------------------------------------------------------
def simulate_elasticsearch_logs(es_url, count, inject_errors=False):
    print(f"\n📜 [2/3] Elasticsearch'e Yapılandırılmış Loglar Gönderiliyor ({es_url})...")
    date_suffix = get_today_index_suffix()
    docker_index = f"novashop-docker-{date_suffix}"
    k8s_index = f"novashop-k8s-{date_suffix}"
    jenkins_index = f"novashop-jenkins-{date_suffix}"

    # 1. Mikroservis Log Şablonları (Docker & Kubernetes Pods)
    log_templates = [
        ("INFO", "User logged in successfully", "novashop-ui", 200),
        ("INFO", "Item added to shopping cart", "novashop-cart", 200),
        ("INFO", "Catalog search query executed", "novashop-catalog", 200),
        ("INFO", "Payment authorization granted via Stripe", "novashop-checkout", 200),
        ("INFO", "Order confirmed and persistence stored", "novashop-orders", 201),
        ("WARN", "Cache miss on product details, querying catalog memory", "novashop-catalog", 200),
        ("WARN", "High memory consumption detected in cart session cache", "novashop-cart", 200),
        ("ERROR", "External payment provider timeout after 5000ms", "novashop-checkout", 504),
        ("ERROR", "Orders persistence error: failed to serialize order state", "novashop-orders", 500),
        ("ERROR", "NullPointerException during discount voucher validation", "novashop-checkout", 500),
    ]

    # 2. Jenkins CI/CD Pipeline Log Şablonları
    jenkins_templates = [
        ("INFO", "[Pipeline] { (Declarative: Checkout SCM)", "novashop-pipeline", "Checkout"),
        ("INFO", "Selected Git commit: 4a2f81c feat(checkout): add idempotent token support", "novashop-pipeline", "Checkout"),
        ("INFO", "[Pipeline] { (Stage: Maven Unit Tests)", "novashop-pipeline", "Unit-Tests"),
        ("INFO", "[INFO] Tests run: 48, Failures: 0, Errors: 0, Skipped: 0", "novashop-pipeline", "Unit-Tests"),
        ("INFO", "[Pipeline] { (Stage: SonarQube Quality Gate)", "novashop-pipeline", "SonarQube"),
        ("INFO", "ANALYSIS SUCCESSFUL. Quality Gate status: PASSED (Bugs: 0, Vulnerabilities: 0)", "novashop-pipeline", "SonarQube"),
        ("INFO", "[Pipeline] { (Stage: Trivy Container Security Scan)", "novashop-pipeline", "Trivy-Scan"),
        ("INFO", "Trivy: Total: 0 (CRITICAL: 0, HIGH: 0, MEDIUM: 2, LOW: 5). Security Gate PASSED.", "novashop-pipeline", "Trivy-Scan"),
        ("INFO", "[Pipeline] { (Stage: Docker Image Push)", "novashop-pipeline", "Docker-Push"),
        ("INFO", "Pushed image: registry.novashop.local/novashop/checkout:v1.2.4 (digest: sha256:8f2a...)", "novashop-pipeline", "Docker-Push"),
        ("INFO", "[Pipeline] { (Stage: Helm GitOps Sync)", "novashop-pipeline", "GitOps-Deploy"),
        ("INFO", "ArgoCD sync completed successfully: Application 'novashop' is Synced & Healthy.", "novashop-pipeline", "GitOps-Deploy"),
        ("WARN", "Node.js npm audit found 1 low severity dependency warning", "novashop-pipeline", "Unit-Tests"),
        ("ERROR", "SonarQube Quality Gate FAILED: 1 Security Vulnerability introduced in CheckoutService.java:44", "novashop-pipeline", "SonarQube"),
        ("ERROR", "Trivy scan detected 1 CRITICAL CVE in base image node:18-alpine. Build ABORTED.", "novashop-pipeline", "Trivy-Scan"),
    ]

    indexed = 0
    bulk_lines = []

    for i in range(count):
        trace_id = hex_id(16)
        span_id = hex_id(8)
        user_id = f"usr-{random.randint(1000, 9999)}"

        if inject_errors:
            level, msg, srv, status = random.choice([t for t in log_templates if t[0] == "ERROR"])
        else:
            weights = [30, 25, 20, 10, 5, 4, 3, 1, 1, 1]
            idx = random.choices(range(len(log_templates)), weights=weights)[0]
            level, msg, srv, status = log_templates[idx]

        # A. Docker Konteyner Logu
        doc_docker = {
            "@timestamp": get_iso_timestamp(),
            "service": srv,
            "level": level,
            "message": msg,
            "user_id": user_id,
            "trace_id": trace_id,
            "span_id": span_id,
            "http_status": status,
            "log_source": "docker_container",
            "duration_ms": random.randint(15, 650) if level != "ERROR" else random.randint(3000, 5200),
            "amount": round(random.uniform(25.0, 850.0), 2) if "Order" in msg or "Payment" in msg else None
        }
        bulk_lines.append(json.dumps({"index": {"_index": docker_index}}))
        bulk_lines.append(json.dumps(doc_docker))
        indexed += 1

        # B. Kubernetes Pod Logu (Kind cluster simülasyonu)
        pod_suffix = hex_id(3)
        doc_k8s = {
            "@timestamp": get_iso_timestamp(),
            "service": srv,
            "level": level,
            "message": f"[{srv.upper()}] {msg}",
            "trace_id": trace_id,
            "span_id": span_id,
            "log_source": "kubernetes_pod",
            "kubernetes": {
                "namespace": "novashop",
                "pod_name": f"{srv}-{pod_suffix}",
                "container_name": srv.replace("novashop-", ""),
                "host": "kind-control-plane"
            }
        }
        bulk_lines.append(json.dumps({"index": {"_index": k8s_index}}))
        bulk_lines.append(json.dumps(doc_k8s))
        indexed += 1

    # C. Jenkins CI/CD Pipeline Logları
    jenkins_count = max(3, count // 3)
    for j in range(jenkins_count):
        build_num = random.randint(35, 52)
        if inject_errors and random.random() < 0.6:
            j_level, j_msg, j_pipe, j_stage = random.choice([t for t in jenkins_templates if t[0] == "ERROR"])
        else:
            j_level, j_msg, j_pipe, j_stage = random.choice(jenkins_templates)

        doc_jenkins = {
            "@timestamp": get_iso_timestamp(),
            "service": "jenkins",
            "pipeline": j_pipe,
            "build_number": build_num,
            "stage": j_stage,
            "level": j_level,
            "message": f"[Build #{build_num}] [{j_stage}] {j_msg}",
            "log_source": "jenkins_cicd"
        }
        bulk_lines.append(json.dumps({"index": {"_index": jenkins_index}}))
        bulk_lines.append(json.dumps(doc_jenkins))
        indexed += 1

    payload = "\n".join(bulk_lines) + "\n"
    try:
        r = requests.post(f"{es_url}/_bulk", data=payload, headers={"Content-Type": "application/x-ndjson"}, timeout=10)
        if r.status_code in (200, 201):
            print(f"    ✅ {indexed} adet yapılandırılmış log Elasticsearch'e indekslendi:")
            print(f"       • Docker:     {docker_index}")
            print(f"       • Kubernetes: {k8s_index}")
            print(f"       • Jenkins:    {jenkins_index}")
        else:
            print(f"    ⚠️ Elasticsearch bulk yanıtı: {r.status_code}")
    except Exception as e:
        print(f"    ❌ Elasticsearch bağlantı hatası: {e}")

# ------------------------------------------------------------------------------
# 3. OPENTELEMETRY & JAEGER TRACING SİMÜLASYONU
# ------------------------------------------------------------------------------
def simulate_jaeger_traces(otel_url, count, inject_errors=False):
    print(f"\n🔍 [3/3] OpenTelemetry & Jaeger Dağıtık İzleri (Traces) Gönderiliyor ({otel_url})...")
    sent = 0

    for i in range(count):
        trace_id = hex_id(16)
        ui_span = hex_id(8)
        cart_span = hex_id(8)
        checkout_span = hex_id(8)
        db_span = hex_id(8)

        base_time = time.time() - random.randint(5, 120)
        t0 = int(base_time * 1e9)
        t1 = int((base_time + random.uniform(0.02, 0.05)) * 1e9)
        t2 = int((base_time + random.uniform(0.06, 0.12)) * 1e9)
        t3 = int((base_time + random.uniform(0.13, 0.22)) * 1e9)
        t_end = int((base_time + random.uniform(0.24, 0.35)) * 1e9)

        is_error = inject_errors or (random.random() < 0.1)

        spans_def = [
            {
                "service": "novashop-ui",
                "span": {
                    "traceId": trace_id,
                    "spanId": ui_span,
                    "name": "POST /order/submit",
                    "kind": 2,
                    "startTimeUnixNano": str(t0),
                    "endTimeUnixNano": str(t_end),
                    "attributes": [
                        {"key": "http.method", "value": {"stringValue": "POST"}},
                        {"key": "http.target", "value": {"stringValue": "/order/submit"}},
                        {"key": "http.status_code", "value": {"intValue": 500 if is_error else 200}},
                        {"key": "error", "value": {"boolValue": is_error}}
                    ],
                    "status": {"code": 2 if is_error else 1}
                }
            },
            {
                "service": "novashop-cart",
                "span": {
                    "traceId": trace_id,
                    "spanId": cart_span,
                    "parentSpanId": ui_span,
                    "name": "GET /api/v1/cart/items",
                    "kind": 1,
                    "startTimeUnixNano": str(t0),
                    "endTimeUnixNano": str(t1),
                    "attributes": [
                        {"key": "cart.items_count", "value": {"intValue": random.randint(1, 4)}},
                        {"key": "http.status_code", "value": {"intValue": 200}}
                    ],
                    "status": {"code": 1}
                }
            },
            {
                "service": "novashop-checkout",
                "span": {
                    "traceId": trace_id,
                    "spanId": checkout_span,
                    "parentSpanId": ui_span,
                    "name": "POST /api/v1/checkout/charge",
                    "kind": 1,
                    "startTimeUnixNano": str(t1),
                    "endTimeUnixNano": str(t3),
                    "attributes": [
                        {"key": "payment.provider", "value": {"stringValue": "stripe"}},
                        {"key": "payment.amount", "value": {"doubleValue": round(random.uniform(50.0, 950.0), 2)}},
                        {"key": "http.status_code", "value": {"intValue": 502 if is_error else 200}},
                        {"key": "error", "value": {"boolValue": is_error}}
                    ],
                    "status": {"code": 2 if is_error else 1}
                }
            },
            {
                "service": "novashop-orders-db",
                "span": {
                    "traceId": trace_id,
                    "spanId": db_span,
                    "parentSpanId": checkout_span,
                    "name": "INSERT INTO orders (id, user_id, amount, status)",
                    "kind": 3,
                    "startTimeUnixNano": str(t2),
                    "endTimeUnixNano": str(t3),
                    "attributes": [
                        {"key": "db.system", "value": {"stringValue": "postgresql"}},
                        {"key": "db.operation", "value": {"stringValue": "INSERT"}}
                    ],
                    "status": {"code": 1}
                }
            }
        ]

        resource_spans = []
        for s in spans_def:
            resource_spans.append({
                "resource": {
                    "attributes": [
                        {"key": "service.name", "value": {"stringValue": s["service"]}},
                        {"key": "environment", "value": {"stringValue": "production"}}
                    ]
                },
                "scopeSpans": [{"scope": {"name": "novashop-tracer"}, "spans": [s["span"]]}]
            })

        try:
            r = requests.post(otel_url, json={"resourceSpans": resource_spans}, headers={"Content-Type": "application/json"}, timeout=5)
            if r.status_code == 200:
                sent += 1
        except Exception:
            pass

    print(f"    ✅ {sent}/{count} dağıtık iz (Trace) başarıyla Jaeger'a iletildi.")

# ------------------------------------------------------------------------------
# ANA PROGRAM VE MODLAR
# ------------------------------------------------------------------------------
def main():
    parser = argparse.ArgumentParser(description="NovaShop Canlı Trafik ve Gözlemlenebilirlik Veri Jeneratörü")
    parser.add_argument("--burst", type=int, default=30, help="Tek seferde üretilecek işlem sayısı (Varsayılan: 30)")
    parser.add_argument("--continuous", action="store_true", help="Arka planda sürekli periyodik veri üretimi")
    parser.add_argument("--error-burst", action="store_true", help="SLO alarmını tetikleyecek yoğun hata enjeksiyonu")
    parser.add_argument("--ui-url", default="http://localhost:8888", help="NovaShop UI URL (Varsayılan: http://localhost:8888)")
    parser.add_argument("--es-url", default="http://localhost:9200", help="Elasticsearch URL (Varsayılan: http://localhost:9200)")
    parser.add_argument("--otel-url", default="http://localhost:4318/v1/traces", help="OTel Traces URL")

    args = parser.parse_args()

    print("=" * 78)
    print("🚀 NovaShop Observability Veri ve Trafik Jeneratörü Başlatıldı")
    print(f"   Mod: {'SÜREKLİ (Continuous)' if args.continuous else 'TEK SEFERLİK (Burst: ' + str(args.burst) + ')'}")
    print(f"   Hata Enjeksiyonu (SLO Alarm Testi): {'AÇIK 🚨' if args.error_burst else 'KAPALI'}")
    print("=" * 78)

    ui_target = args.ui_url
    if ui_target == "http://localhost:8888":
        # Otomatik algılama: Önce Kind Kubernetes NodePort (30080) kontrol edilir
        try:
            r = requests.get("http://localhost:30080/actuator/health", timeout=1)
            if r.status_code == 200:
                ui_target = "http://localhost:30080"
        except Exception:
            pass

    cycle = 1
    while True:
        if args.continuous:
            print(f"\n--- [Döngü #{cycle}] Canlı veri akışı üretiliyor... ---")

        simulate_http_traffic(ui_target, args.burst, inject_errors=args.error_burst)
        simulate_elasticsearch_logs(args.es_url, args.burst * 2, inject_errors=args.error_burst)
        simulate_jaeger_traces(args.otel_url, max(5, args.burst // 3), inject_errors=args.error_burst)

        print("\n🎉 Tüm veriler başarıyla enjekte edildi!")
        print("   • Grafana: http://localhost:3000 (RED ve e-ticaret metrikleri güncellendi)")
        print("   • Kibana:  http://localhost:5601 (Discover ve Dashboard logları güncellendi)")
        print("   • Jaeger:  http://localhost:16686 (Yeni izler eklendi)")

        if not args.continuous:
            break

        cycle += 1
        time.sleep(random.randint(3, 7))

if __name__ == "__main__":
    main()
