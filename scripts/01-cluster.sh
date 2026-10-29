#!/usr/bin/env bash
set -euo pipefail

CLUSTER_NAME="${CLUSTER_NAME:-inference-lab}"

if ! command -v docker >/dev/null 2>&1; then
  export KIND_EXPERIMENTAL_PROVIDER=podman
fi

if kind get clusters 2>/dev/null | grep -qx "$CLUSTER_NAME"; then
  echo "Cluster '$CLUSTER_NAME' already exists, skipping create."
else
  kind create cluster --name "$CLUSTER_NAME"
fi

kubectl cluster-info --context "kind-${CLUSTER_NAME}"
