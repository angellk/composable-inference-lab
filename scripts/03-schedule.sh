#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

KUEUE_VERSION="v0.20.0"

kubectl apply --server-side -f "https://github.com/kubernetes-sigs/kueue/releases/download/${KUEUE_VERSION}/manifests.yaml"
kubectl wait --for=condition=Available deployment/kueue-controller-manager -n kueue-system --timeout=180s

kubectl apply -f manifests/schedule/kueue-setup.yaml

echo "Waiting for ClusterQueue to become active..."
sleep 5
kubectl get clusterqueue
kubectl get localqueue -A
