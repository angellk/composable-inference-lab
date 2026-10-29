#!/usr/bin/env bash
# Install/verify prerequisites. Safe to re-run.
# Set CONTAINER_RUNTIME=docker or CONTAINER_RUNTIME=podman to force a choice;
# otherwise this prefers whichever is already running.
set -euo pipefail

command -v kind >/dev/null || { echo "Installing kind..."; brew install kind; }
command -v kubectl >/dev/null || { echo "Installing kubectl..."; brew install kubectl; }
command -v helm >/dev/null || { echo "Installing helm..."; brew install helm; }

OS="$(uname -s)"
RUNTIME="${CONTAINER_RUNTIME:-}"

if [ -z "$RUNTIME" ]; then
  if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
    RUNTIME="docker"
  elif command -v podman >/dev/null 2>&1; then
    RUNTIME="podman"
  elif command -v docker >/dev/null 2>&1; then
    RUNTIME="docker"
  else
    RUNTIME=""
  fi
fi

if [ "$OS" = "Linux" ]; then
  echo "Linux host: neither runtime needs a VM layer."
  if [ "$RUNTIME" = "docker" ] || [ "$RUNTIME" = "podman" ]; then
    echo "Using $RUNTIME (already installed and running natively)."
  else
    echo "Neither docker nor podman found. Install one (e.g. 'sudo apt install docker.io' or 'sudo apt install podman') before continuing." >&2
    exit 1
  fi
else
  # macOS (and other non-Linux hosts): both runtimes need a VM layer.
  case "$RUNTIME" in
    docker)
      echo "Using docker. If this is Docker Desktop, make sure it's running."
      if ! docker info >/dev/null 2>&1; then
        echo "docker CLI found but the daemon isn't responding. If you don't want Docker Desktop," \
             "install colima instead: 'brew install colima docker' then 'colima start --cpu 4 --memory 8 --disk 40'." >&2
        exit 1
      fi
      ;;
    podman)
      echo "Using podman via KIND_EXPERIMENTAL_PROVIDER=podman."
      MACHINE="$(podman machine list --format '{{.Name}}' | head -1 || true)"
      if [ -n "${MACHINE:-}" ]; then
        RUNNING="$(podman machine list --format '{{.Running}}' | head -1 || echo false)"
        if [ "$RUNNING" != "true" ]; then
          echo "Starting podman machine '$MACHINE'..."
          podman machine start "$MACHINE"
        fi
      else
        echo "No podman machine found, creating one (4 CPU / 8GB RAM / 40GB disk)..."
        podman machine init --cpus 4 --memory 8192 --disk-size 40
        podman machine start
        echo "Note: resizing an existing podman machine later (via 'podman machine set') may not" \
             "grow the guest partition automatically; see docs/FINDINGS.md if you hit" \
             "'no space left on device' after a resize."
      fi
      ;;
    *)
      echo "Neither docker nor podman found. On macOS, the quickest path without Docker Desktop" \
           "is colima: 'brew install colima docker' then 'colima start --cpu 4 --memory 8 --disk 40'." >&2
      exit 1
      ;;
  esac
fi

echo "CONTAINER_RUNTIME=$RUNTIME"
echo "Prerequisites OK."
