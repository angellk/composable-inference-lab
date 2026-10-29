#!/usr/bin/env bash
# Install/verify prerequisites. Safe to re-run.
set -euo pipefail

command -v kind >/dev/null || { echo "Installing kind..."; brew install kind; }
command -v kubectl >/dev/null || { echo "Installing kubectl..."; brew install kubectl; }
command -v helm >/dev/null || { echo "Installing helm..."; brew install helm; }

if command -v docker >/dev/null; then
  echo "docker found, will be used by kind."
elif command -v podman >/dev/null; then
  echo "No docker found; using podman via KIND_EXPERIMENTAL_PROVIDER=podman."
  echo "export KIND_EXPERIMENTAL_PROVIDER=podman" >> "${BASH_ENV:-/dev/null}" 2>/dev/null || true
  MACHINE="$(podman machine list --format '{{.Name}}' | head -1 || true)"
  if [ -n "${MACHINE:-}" ]; then
    RUNNING="$(podman machine list --format '{{.Running}}' | head -1 || echo false)"
    if [ "$RUNNING" != "true" ]; then
      echo "Resizing and starting podman machine '$MACHINE' (4 CPU / 8GB RAM / 40GB disk)..."
      podman machine set --cpus 4 --memory 8192 --disk-size 40 "$MACHINE" || true
      podman machine start "$MACHINE"
    fi
  else
    echo "No podman machine found, creating one (4 CPU / 8GB RAM / 40GB disk)..."
    podman machine init --cpus 4 --memory 8192 --disk-size 40
    podman machine start
  fi
else
  echo "Neither docker nor podman found. Install one before continuing." >&2
  exit 1
fi

echo "Prerequisites OK."
