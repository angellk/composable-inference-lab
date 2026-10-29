#!/usr/bin/env bash
# Bursty, mostly-idle agent pattern: a long idle period, then a sudden
# concurrent burst. Mirrors the "bursty, mostly-idle, stateful agent
# workload" shape that motivates autoscaling (e.g. KEDA + EPP metrics).
# Actually running an autoscaler is out of scope for this lab, but this
# traffic shape is useful for observing queue/latency behavior under it.
set -euo pipefail
ENDPOINT="${ENDPOINT:-http://localhost:8080/v1/completions}"
MODEL="${MODEL:-lab-dummy-model}"
IDLE_SECONDS="${IDLE_SECONDS:-15}"
BURST_SIZE="${BURST_SIZE:-20}"

echo "Idling for ${IDLE_SECONDS}s to simulate a mostly-idle agent..."
sleep "$IDLE_SECONDS"

echo "Bursting ${BURST_SIZE} concurrent requests..."
for ((i = 1; i <= BURST_SIZE; i++)); do
  curl -s "$ENDPOINT" \
    -H "Content-Type: application/json" \
    -d "{\"model\": \"${MODEL}\", \"prompt\": \"burst request ${i}\", \"max_tokens\": 32}" \
    -o /dev/null -w "burst-${i} %{http_code} %{time_total}s\n" &
done
wait
echo "Burst complete. Compare per-request latency within the burst to a steady-state single request."
