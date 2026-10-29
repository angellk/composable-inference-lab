#!/usr/bin/env bash
# Tool-calling / ReAct-style burst: short "planning" calls interleaved with
# longer "generation" calls, irregular timing, to exercise queueing and the
# gateway's backpressure/retry behavior.
set -euo pipefail
ENDPOINT="${ENDPOINT:-http://localhost:8080/v1/completions}"
MODEL="${MODEL:-lab-dummy-model}"
ROUNDS="${ROUNDS:-10}"

for ((i = 1; i <= ROUNDS; i++)); do
  # Short "planning" call
  curl -s "$ENDPOINT" -H "Content-Type: application/json" \
    -d "{\"model\": \"${MODEL}\", \"prompt\": \"plan step ${i}\", \"max_tokens\": 8}" \
    -o /dev/null -w "planning call %{http_code} %{time_total}s\n" &

  # Irregular gap, mimicking tool-execution latency
  sleep "0.$((RANDOM % 9 + 1))"

  # Longer "generation" call
  curl -s "$ENDPOINT" -H "Content-Type: application/json" \
    -d "{\"model\": \"${MODEL}\", \"prompt\": \"generate result for step ${i}\", \"max_tokens\": 128}" \
    -o /dev/null -w "generation call %{http_code} %{time_total}s\n" &

  wait
  sleep "0.$((RANDOM % 5))"
done
