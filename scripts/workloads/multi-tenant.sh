#!/usr/bin/env bash
# Concurrent multi-tenant load: several simulated "tenants" sending concurrent
# requests tagged with different x-llm-d-inference-fairness-id header values,
# to exercise fairness rather than raw throughput.
set -euo pipefail
ENDPOINT="${ENDPOINT:-http://localhost:8080/v1/completions}"
MODEL="${MODEL:-lab-dummy-model}"
TENANTS="${TENANTS:-3}"
REQUESTS_PER_TENANT="${REQUESTS_PER_TENANT:-10}"

run_tenant() {
  local tenant_id="$1"
  for ((r = 1; r <= REQUESTS_PER_TENANT; r++)); do
    curl -s "$ENDPOINT" \
      -H "Content-Type: application/json" \
      -H "x-llm-d-inference-fairness-id: tenant-${tenant_id}" \
      -d "{\"model\": \"${MODEL}\", \"prompt\": \"tenant ${tenant_id} request ${r}\", \"max_tokens\": 32}" \
      -o /dev/null -w "tenant-${tenant_id} req-${r} %{http_code} %{time_total}s\n"
  done
}

for ((t = 1; t <= TENANTS; t++)); do
  run_tenant "$t" &
done
wait
echo "All tenants done. Inspect response latencies above for fairness skew across tenants."
