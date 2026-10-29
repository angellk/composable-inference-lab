#!/usr/bin/env bash
set -euo pipefail
CLUSTER_NAME="${CLUSTER_NAME:-inference-lab}"
kind delete cluster --name "$CLUSTER_NAME"
