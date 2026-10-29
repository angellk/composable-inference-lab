#!/usr/bin/env python3
"""Concurrent multi-tenant load: several simulated "tenants" sending concurrent
requests tagged with different x-llm-d-inference-fairness-id header values,
to exercise fairness rather than raw throughput.

Sends a mix of chat generation, text generation, and embeddings requests per
tenant, matching the request-type mix described in docs/USE_CASE.md, instead
of one repeated request shape. All three request types are confirmed to work
against llm-d-inference-sim (checked directly: it returns HTTP 200 for
/v1/completions, /v1/chat/completions, and /v1/embeddings alike)."""
import os
import time
from concurrent.futures import ThreadPoolExecutor, as_completed

import requests

ENDPOINT = os.environ.get("ENDPOINT", "http://localhost:8080")
MODEL = os.environ.get("MODEL", "lab-dummy-model")
TENANTS = int(os.environ.get("TENANTS", "3"))
REQUESTS_PER_TENANT = int(os.environ.get("REQUESTS_PER_TENANT", "10"))

REQUEST_TYPES = ["chat", "text", "embedding"]


def build_request(request_type, tenant_id, request_num):
    if request_type == "chat":
        return (
            f"{ENDPOINT}/v1/chat/completions",
            {
                "model": MODEL,
                "messages": [
                    {"role": "user", "content": f"tenant {tenant_id} chat request {request_num}"}
                ],
                "max_tokens": 32,
            },
        )
    if request_type == "text":
        return (
            f"{ENDPOINT}/v1/completions",
            {
                "model": MODEL,
                "prompt": f"tenant {tenant_id} text request {request_num}",
                "max_tokens": 32,
            },
        )
    if request_type == "embedding":
        return (
            f"{ENDPOINT}/v1/embeddings",
            {"model": MODEL, "input": f"tenant {tenant_id} embedding request {request_num}"},
        )
    raise ValueError(f"unknown request type: {request_type}")


def send_request(tenant_id, request_num):
    request_type = REQUEST_TYPES[request_num % len(REQUEST_TYPES)]
    url, body = build_request(request_type, tenant_id, request_num)
    headers = {"x-llm-d-inference-fairness-id": f"tenant-{tenant_id}"}
    start = time.perf_counter()
    try:
        resp = requests.post(url, json=body, headers=headers, timeout=30)
        elapsed = time.perf_counter() - start
        return {
            "tenant": tenant_id,
            "request_type": request_type,
            "status": resp.status_code,
            "elapsed": elapsed,
            "ok": resp.ok,
        }
    except requests.RequestException as exc:
        elapsed = time.perf_counter() - start
        return {
            "tenant": tenant_id,
            "request_type": request_type,
            "status": None,
            "elapsed": elapsed,
            "ok": False,
            "error": str(exc),
        }


def percentile(values, pct):
    if not values:
        return float("nan")
    ordered = sorted(values)
    k = (len(ordered) - 1) * (pct / 100)
    f = int(k)
    c = min(f + 1, len(ordered) - 1)
    if f == c:
        return ordered[f]
    return ordered[f] + (ordered[c] - ordered[f]) * (k - f)


def summarize(label, results):
    latencies = [r["elapsed"] for r in results]
    successes = sum(1 for r in results if r["ok"])
    total = len(results)
    rate = (successes / total * 100) if total else 0.0
    p50 = percentile(latencies, 50)
    p95 = percentile(latencies, 95)
    print(f"{label}: {successes}/{total} succeeded ({rate:.1f}%), p50={p50:.3f}s, p95={p95:.3f}s")


def main():
    jobs = [
        (tenant_id, request_num)
        for tenant_id in range(1, TENANTS + 1)
        for request_num in range(1, REQUESTS_PER_TENANT + 1)
    ]
    results = []
    with ThreadPoolExecutor(max_workers=max(TENANTS, 1) * 2) as pool:
        futures = [pool.submit(send_request, t, r) for t, r in jobs]
        for future in as_completed(futures):
            result = future.result()
            results.append(result)
            status = result["status"] if result["status"] is not None else "ERR"
            print(f"tenant-{result['tenant']} {result['request_type']} HTTP {status} {result['elapsed']:.3f}s")

    print()
    print("=== Summary ===")
    for tenant_id in range(1, TENANTS + 1):
        tenant_results = [r for r in results if r["tenant"] == tenant_id]
        summarize(f"tenant-{tenant_id}", tenant_results)

    print()
    for request_type in REQUEST_TYPES:
        type_results = [r for r in results if r["request_type"] == request_type]
        summarize(request_type, type_results)

    print()
    summarize("overall", results)
    print(
        "Inspect per-tenant latency and success rate above for fairness skew "
        "across tenants, not just overall throughput."
    )


if __name__ == "__main__":
    main()
