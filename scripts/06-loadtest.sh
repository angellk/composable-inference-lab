#!/usr/bin/env bash
# Load test against the gateway's OpenAI-compatible endpoint.
#
# NVIDIA's AIPerf (successor to GenAI-Perf, both Apache-2.0, OpenAI-compatible,
# vendor-neutral) is the recommended tool for rigorous LLM inference benchmarking
# (TTFT, inter-token latency, throughput): https://github.com/ai-dynamo/aiperf
# It's not wired into this script because installing it (pip/uv + model tokenizer
# config) is more setup than fits a quick lab script. If you have it available:
#
#   uvx aiperf profile --model lab-dummy-model --url http://localhost:8080 \
#     --endpoint-type completions --concurrency 10 --request-count 100
#
# This script is a dependency-free fallback using curl, measuring basic
# per-request latency under concurrency. It does not measure true TTFT or
# inter-token latency for streaming responses — use AIPerf for that.
set -euo pipefail
ENDPOINT="${ENDPOINT:-http://localhost:8080/v1/completions}"
MODEL="${MODEL:-lab-dummy-model}"
CONCURRENCY="${CONCURRENCY:-10}"
REQUESTS="${REQUESTS:-100}"

echo "Load testing ${ENDPOINT} — ${REQUESTS} requests at concurrency ${CONCURRENCY}"
echo "(dependency-free curl fallback; use AIPerf for rigorous TTFT/inter-token-latency measurement)"
echo ""

seq 1 "$REQUESTS" | xargs -P "$CONCURRENCY" -I{} \
  curl -s -o /dev/null -w "req-{} %{http_code} total=%{time_total}s connect=%{time_connect}s\n" \
  "$ENDPOINT" \
  -H "Content-Type: application/json" \
  -d "{\"model\": \"${MODEL}\", \"prompt\": \"load test request {}\", \"max_tokens\": 32}"
