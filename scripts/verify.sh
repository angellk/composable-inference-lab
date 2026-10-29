#!/usr/bin/env bash
# Acceptance tests for each layer. Fails loudly rather than reporting a false "it works".
set -euo pipefail
cd "$(dirname "$0")/.."

echo "=== Gateway ==="
kubectl get gatewayclass agentgateway -o jsonpath='{.status.conditions[?(@.type=="Accepted")].status}' | grep -q True && echo "OK: GatewayClass Accepted"
kubectl get gateway -n inference-lab llm-d-inference-gateway -o jsonpath='{.status.conditions[?(@.type=="Programmed")].status}' | grep -q True && echo "OK: Gateway Programmed"

echo "=== Schedule ==="
kubectl get clusterqueue cluster-queue -o jsonpath='{.status.conditions[?(@.type=="Active")].status}' | grep -q True && echo "OK: ClusterQueue Active"

echo "=== Serve ==="
kubectl get inferencepool -n inference-lab llm-d-router -o jsonpath='{.status.parent[0].conditions[?(@.type=="Accepted")].status}' | grep -q True && echo "OK: InferencePool Accepted"
kubectl get httproute -n inference-lab llm-d-router -o jsonpath='{.status.parents[0].conditions[?(@.type=="Accepted")].status}' | grep -q True && echo "OK: HTTPRoute Accepted"

echo ""
echo "To send a live request through the full chain:"
echo "  kubectl port-forward -n inference-lab svc/llm-d-inference-gateway 8080:80 &"
echo "  curl -s http://localhost:8080/v1/completions \\"
echo "    -H 'Content-Type: application/json' \\"
echo "    -d '{\"model\": \"lab-dummy-model\", \"prompt\": \"hello\", \"max_tokens\": 16}'"
echo ""
echo "=== Observe ==="
echo "To run the trace-correlation acceptance test, see README.md and docs/FINDINGS.md:"
echo "send one request with a known W3C traceparent header, then look up that exact"
echo "trace ID in the Jaeger UI (kubectl port-forward -n observe svc/jaeger 16686:16686)"
echo "and confirm valid parent/child spans across gateway -> EPP. Note: the serve-layer"
echo "span cannot be proven with llm-d-inference-sim (see docs/FINDINGS.md, finding #5)."
