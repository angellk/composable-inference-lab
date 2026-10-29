#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

KUEUE_VERSION="v0.20.0"

kubectl apply --server-side -f "https://github.com/kubernetes-sigs/kueue/releases/download/${KUEUE_VERSION}/manifests.yaml"
kubectl wait --for=condition=Available deployment/kueue-controller-manager -n kueue-system --timeout=180s

# The webhook can take a few seconds past "Available" to actually start
# serving; retry the apply rather than failing on the first attempt.
for i in 1 2 3 4 5; do
  if kubectl apply -f manifests/schedule/kueue-setup.yaml; then
    break
  fi
  echo "Kueue webhook not ready yet, retrying in 5s (attempt $i/5)..."
  sleep 5
done

echo "Waiting for ClusterQueue to become active..."
sleep 5
kubectl get clusterqueue
kubectl get localqueue -A
