#!/usr/bin/env bash
# Multi-turn conversational loop: growing context per turn, to exercise
# prefix-cache / KV-cache locality claims. Assumes a port-forward to the
# gateway is already running on localhost:8080 (see scripts/verify.sh).
set -euo pipefail
ENDPOINT="${ENDPOINT:-http://localhost:8080/v1/completions}"
MODEL="${MODEL:-lab-dummy-model}"
TURNS="${TURNS:-5}"

context=""
for ((i = 1; i <= TURNS; i++)); do
  prompt="${context}Turn ${i}: tell me one more fact about Kubernetes. "
  echo "--- turn $i (prompt length: ${#prompt} chars) ---"
  response=$(curl -s "$ENDPOINT" \
    -H "Content-Type: application/json" \
    -d "{\"model\": \"${MODEL}\", \"prompt\": $(printf '%s' "$prompt" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))'), \"max_tokens\": 32}")
  echo "$response"
  context="${prompt}$(echo "$response" | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d.get("choices",[{}])[0].get("text",""))' 2>/dev/null || echo "")"
done
