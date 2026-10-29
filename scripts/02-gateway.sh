#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

GATEWAY_API_VERSION="v1.6.1"
AGENTGATEWAY_VERSION="v1.1.0"

kubectl apply --server-side -f "https://github.com/kubernetes-sigs/gateway-api/releases/download/${GATEWAY_API_VERSION}/experimental-install.yaml"

helm upgrade --install agentgateway-crds oci://cr.agentgateway.dev/charts/agentgateway-crds \
  --namespace agentgateway-system --create-namespace --version "${AGENTGATEWAY_VERSION}"
helm upgrade --install agentgateway oci://cr.agentgateway.dev/charts/agentgateway \
  --namespace agentgateway-system --create-namespace --version "${AGENTGATEWAY_VERSION}" \
  --set inferenceExtension.enabled=true

kubectl apply -k "github.com/kubernetes-sigs/gateway-api-inference-extension/config/crd"

kubectl apply -f manifests/gateway/gateway.yaml

echo "Waiting for GatewayClass/agentgateway to be accepted..."
kubectl wait --for=condition=Accepted gatewayclass/agentgateway --timeout=120s || true
kubectl get gatewayclass agentgateway
kubectl get gateway -n inference-lab llm-d-inference-gateway
