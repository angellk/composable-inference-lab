#!/usr/bin/env bash
# Set CONTAINER_RUNTIME=docker or CONTAINER_RUNTIME=podman to force a choice;
# otherwise this prefers whichever is already running (same detection as
# 00-prereqs.sh).
set -euo pipefail

CLUSTER_NAME="${CLUSTER_NAME:-inference-lab}"
RUNTIME="${CONTAINER_RUNTIME:-}"

if [ -z "$RUNTIME" ]; then
  if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
    RUNTIME="docker"
  elif command -v podman >/dev/null 2>&1; then
    RUNTIME="podman"
  else
    echo "Neither a running docker nor podman found. Run scripts/00-prereqs.sh first." >&2
    exit 1
  fi
fi

if [ "$RUNTIME" = "podman" ]; then
  export KIND_EXPERIMENTAL_PROVIDER=podman
fi

echo "Using CONTAINER_RUNTIME=$RUNTIME"

if kind get clusters 2>/dev/null | grep -qx "$CLUSTER_NAME"; then
  echo "Cluster '$CLUSTER_NAME' already exists, skipping create."
else
  kind create cluster --name "$CLUSTER_NAME"
fi

kubectl cluster-info --context "kind-${CLUSTER_NAME}"
