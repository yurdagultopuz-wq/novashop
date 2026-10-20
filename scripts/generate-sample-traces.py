#!/usr/bin/env python3
"""
NovaShop — OpenTelemetry Distributed Tracing Generator
Simulates realistic distributed traces across all NovaShop microservices
and exports them to the OpenTelemetry Collector / Jaeger.
"""

import random
import time
import uuid
import requests

OTEL_ENDPOINT = "http://localhost:4466/v1/traces"

def hex_id(n_bytes):
    return uuid.uuid4().hex[:n_bytes * 2]

def send_trace(spans_def):
    resource_spans = []
    for s in spans_def:
        resource_spans.append({
            "resource": {
                "attributes": [
                    {"key": "service.name", "value": {"stringValue": s["service"]}},
                    {"key": "telemetry.sdk.language", "value": {"stringValue": s.get("lang", "java")}},
                    {"key": "environment", "value": {"stringValue": "production"}}
                ]
            },
            "scopeSpans": [
                {
                    "scope": {"name": "novashop-instrumentation"},
                    "spans": [s["span"]]
                }
            ]
        })
    try:
        res = requests.post(OTEL_ENDPOINT, json={"resourceSpans": resource_spans}, headers={"Content-Type": "application/json"}, timeout=5)
        return res.status_code
    except Exception as e:
        print(f"Error sending trace: {e}")
        return 0

def generate_traces():
    print("🚀 Generating realistic distributed traces for NovaShop...")

    # 1. Successful Full Checkout Flow (UI -> Cart -> Checkout -> Orders DB)
    for i in range(15):
        trace_id = hex_id(16)
        ui_span = hex_id(8)
        cart_span = hex_id(8)
        checkout_span = hex_id(8)
        db_span = hex_id(8)

        base_time = time.time() - random.randint(10, 600)
        t0 = int(base_time * 1e9)
        t1 = int((base_time + random.uniform(0.02, 0.05)) * 1e9)
        t2 = int((base_time + random.uniform(0.06, 0.12)) * 1e9)
        t3 = int((base_time + random.uniform(0.13, 0.22)) * 1e9)
        t_end = int((base_time + random.uniform(0.24, 0.35)) * 1e9)

        spans = [
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
                        {"key": "http.status_code", "value": {"intValue": 200}},
                        {"key": "user.id", "value": {"stringValue": f"usr-{random.randint(1000, 9999)}"}}
                    ],
                    "status": {"code": 1}
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
                        {"key": "http.method", "value": {"stringValue": "GET"}},
                        {"key": "cart.items_count", "value": {"intValue": random.randint(1, 5)}},
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
                        {"key": "http.method", "value": {"stringValue": "POST"}},
                        {"key": "payment.provider", "value": {"stringValue": "stripe"}},
                        {"key": "payment.currency", "value": {"stringValue": "TRY"}},
                        {"key": "payment.amount", "value": {"doubleValue": round(random.uniform(50.0, 1200.0), 2)}},
                        {"key": "http.status_code", "value": {"intValue": 200}}
                    ],
                    "status": {"code": 1}
                }
            },
            {
                "service": "novashop-orders-db",
                "lang": "sql",
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
                        {"key": "db.name", "value": {"stringValue": "novashop_orders"}},
                        {"key": "db.operation", "value": {"stringValue": "INSERT"}}
                    ],
                    "status": {"code": 1}
                }
            }
        ]
        send_trace(spans)

    # 2. Product Catalog Browsing (UI -> Catalog Service -> Cache)
    for i in range(12):
        trace_id = hex_id(16)
        ui_span = hex_id(8)
        cat_span = hex_id(8)

        base_time = time.time() - random.randint(5, 300)
        t0 = int(base_time * 1e9)
        t1 = int((base_time + random.uniform(0.01, 0.04)) * 1e9)
        t_end = int((base_time + random.uniform(0.05, 0.09)) * 1e9)

        category = random.choice(["electronics", "clothing", "books", "home"])
        spans = [
            {
                "service": "novashop-ui",
                "span": {
                    "traceId": trace_id,
                    "spanId": ui_span,
                    "name": f"GET /products?category={category}",
                    "kind": 2,
                    "startTimeUnixNano": str(t0),
                    "endTimeUnixNano": str(t_end),
                    "attributes": [
                        {"key": "http.method", "value": {"stringValue": "GET"}},
                        {"key": "http.target", "value": {"stringValue": f"/products?category={category}"}},
                        {"key": "http.status_code", "value": {"intValue": 200}}
                    ],
                    "status": {"code": 1}
                }
            },
            {
                "service": "novashop-catalog",
                "span": {
                    "traceId": trace_id,
                    "spanId": cat_span,
                    "parentSpanId": ui_span,
                    "name": "GET /api/v1/catalog/items",
                    "kind": 1,
                    "startTimeUnixNano": str(t0),
                    "endTimeUnixNano": str(t1),
                    "attributes": [
                        {"key": "catalog.category", "value": {"stringValue": category}},
                        {"key": "cache.hit", "value": {"boolValue": random.choice([True, False])}},
                        {"key": "http.status_code", "value": {"intValue": 200}}
                    ],
                    "status": {"code": 1}
                }
            }
        ]
        send_trace(spans)

    # 3. Failed Transactions (Payment Declined / 500 Error for Troubleshooting Demo)
    for i in range(4):
        trace_id = hex_id(16)
        ui_span = hex_id(8)
        checkout_span = hex_id(8)

        base_time = time.time() - random.randint(10, 180)
        t0 = int(base_time * 1e9)
        t1 = int((base_time + random.uniform(0.2, 0.45)) * 1e9)
        t_end = int((base_time + random.uniform(0.46, 0.6)) * 1e9)

        spans = [
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
                        {"key": "http.status_code", "value": {"intValue": 500}},
                        {"key": "error", "value": {"boolValue": True}}
                    ],
                    "status": {"code": 2, "message": "Internal Server Error"}
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
                    "startTimeUnixNano": str(t0),
                    "endTimeUnixNano": str(t1),
                    "attributes": [
                        {"key": "http.status_code", "value": {"intValue": 502}},
                        {"key": "error", "value": {"boolValue": True}},
                        {"key": "error.type", "value": {"stringValue": "PaymentGatewayTimeoutException"}},
                        {"key": "error.message", "value": {"stringValue": "External banking gateway connection timed out after 5000ms"}}
                    ],
                    "status": {"code": 2, "message": "Gateway Timeout"}
                }
            }
        ]
        send_trace(spans)

    print("✅ Distributed traces generated successfully!")

if __name__ == "__main__":
    generate_traces()
