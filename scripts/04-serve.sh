#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

kubectl apply -f manifests/serve/llm-d-sim-deployment.yaml
kubectl wait --for=condition=Available deployment/llm-d-sim -n inference-lab --timeout=180s

WORKDIR="$(mktemp -d)"
git clone --depth 1 https://github.com/llm-d/llm-d.git "$WORKDIR/llm-d"

# The chart's own base.values.yaml defaults router.epp.resources and
# router.proxy.resources to 4 CPU / 8Gi each, a production-sized default
# that won't schedule on a lab-scale node. See docs/FINDINGS.md for how this
# was found.
helm upgrade --install llm-d-router oci://ghcr.io/llm-d/charts/llm-d-router-gateway --version v0 \
  -n inference-lab \
  -f "$WORKDIR/llm-d/guides/recipes/router/base.values.yaml" \
  --set router.modelServers.matchLabels.app=llm-d-sim \
  --set provider.name=none \
  --set httpRoute.create=true \
  --set httpRoute.inferenceGatewayName=llm-d-inference-gateway \
  --set httpRoute.inferenceGatewayNamespace=inference-lab \
  --set router.epp.resources.requests.cpu=250m \
  --set router.epp.resources.requests.memory=256Mi \
  --set router.epp.resources.limits.memory=512Mi \
  --set router.proxy.resources.requests.cpu=100m \
  --set router.proxy.resources.requests.memory=128Mi \
  --set router.proxy.resources.limits.memory=256Mi \
  --set router.tracing.enabled=true \
  --set router.tracing.otelExporterEndpoint="http://jaeger.observe.svc:4317" \
  --set router.tracing.sampling.samplerArg="1.0"

rm -rf "$WORKDIR"

echo "Waiting for InferencePool/HTTPRoute to be accepted..."
sleep 5
kubectl get inferencepool -n inference-lab
kubectl get httproute -n inference-lab
