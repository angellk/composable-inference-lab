#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

kubectl apply -f manifests/observe/jaeger.yaml
kubectl wait --for=condition=Available deployment/jaeger -n observe --timeout=180s

echo "Jaeger UI: kubectl port-forward -n observe svc/jaeger 16686:16686"
echo "Then open http://localhost:16686"
