#!/usr/bin/env python3
"""Tool-calling / ReAct-style burst: short "planning" calls interleaved with
longer "generation" calls, irregular timing, to exercise queueing and the
gateway's backpressure/retry behavior."""
import os
import random
import time
from concurrent.futures import ThreadPoolExecutor

import requests

ENDPOINT = os.environ.get("ENDPOINT", "http://localhost:8080")
MODEL = os.environ.get("MODEL", "lab-dummy-model")
ROUNDS = int(os.environ.get("ROUNDS", "10"))


def call(label, prompt, max_tokens):
    start = time.perf_counter()
    resp = requests.post(
        f"{ENDPOINT}/v1/completions",
        json={"model": MODEL, "prompt": prompt, "max_tokens": max_tokens},
        timeout=30,
    )
    elapsed = time.perf_counter() - start
    print(f"{label} HTTP {resp.status_code} {elapsed:.3f}s")


def main():
    with ThreadPoolExecutor(max_workers=2) as pool:
        for i in range(1, ROUNDS + 1):
            planning = pool.submit(call, f"planning call {i}", f"plan step {i}", 8)
            time.sleep(random.uniform(0.1, 0.9))
            generation = pool.submit(
                call, f"generation call {i}", f"generate result for step {i}", 128
            )
            planning.result()
            generation.result()
            time.sleep(random.uniform(0, 0.5))


if __name__ == "__main__":
    main()
