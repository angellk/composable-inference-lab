#!/usr/bin/env python3
"""Bursty, mostly-idle agent pattern: a long idle period, then a sudden
concurrent burst. Mirrors the "bursty, mostly-idle, stateful agent workload"
shape that motivates autoscaling (e.g. KEDA + EPP metrics). Actually running
an autoscaler is out of scope for this lab, but this traffic shape is useful
for observing queue and latency behavior under it."""
import os
import time
from concurrent.futures import ThreadPoolExecutor

import requests

ENDPOINT = os.environ.get("ENDPOINT", "http://localhost:8080")
MODEL = os.environ.get("MODEL", "lab-dummy-model")
IDLE_SECONDS = int(os.environ.get("IDLE_SECONDS", "15"))
BURST_SIZE = int(os.environ.get("BURST_SIZE", "20"))


def fire(i):
    start = time.perf_counter()
    resp = requests.post(
        f"{ENDPOINT}/v1/completions",
        json={"model": MODEL, "prompt": f"burst request {i}", "max_tokens": 32},
        timeout=30,
    )
    elapsed = time.perf_counter() - start
    print(f"burst-{i} HTTP {resp.status_code} {elapsed:.3f}s")


def main():
    print(f"Idling for {IDLE_SECONDS}s to simulate a mostly-idle agent...")
    time.sleep(IDLE_SECONDS)
    print(f"Bursting {BURST_SIZE} concurrent requests...")
    with ThreadPoolExecutor(max_workers=BURST_SIZE) as pool:
        list(pool.map(fire, range(1, BURST_SIZE + 1)))
    print("Burst complete. Compare per-request latency within the burst to a steady-state single request.")


if __name__ == "__main__":
    main()
