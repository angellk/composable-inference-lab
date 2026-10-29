#!/usr/bin/env python3
"""Multi-turn conversational loop: growing context per turn, to exercise
prefix-cache / KV-cache locality. Assumes a port-forward to the gateway is
already running (see scripts/verify.sh)."""
import os
import time

import requests

ENDPOINT = os.environ.get("ENDPOINT", "http://localhost:8080")
MODEL = os.environ.get("MODEL", "lab-dummy-model")
TURNS = int(os.environ.get("TURNS", "5"))


def main():
    context = ""
    for i in range(1, TURNS + 1):
        prompt = f"{context}Turn {i}: tell me one more fact about Kubernetes. "
        start = time.perf_counter()
        resp = requests.post(
            f"{ENDPOINT}/v1/completions",
            json={"model": MODEL, "prompt": prompt, "max_tokens": 32},
            timeout=30,
        )
        elapsed = time.perf_counter() - start
        print(f"--- turn {i} (prompt length: {len(prompt)} chars, {elapsed:.3f}s, HTTP {resp.status_code}) ---")
        text = ""
        if resp.ok:
            data = resp.json()
            text = data.get("choices", [{}])[0].get("text", "")
            print(text)
        else:
            print(resp.text)
        context = prompt + text


if __name__ == "__main__":
    main()
