#!/usr/bin/env bash
# Build the Electron image. Nothing is installed on the host.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IMAGE="granola-for-linux:dev"

# The Electron version must match the bundle's; see docs/findings.md for how
# to read it. Override with: ELECTRON_VERSION=42.7.0 ./scripts/build-env.sh
ELECTRON_VERSION="${ELECTRON_VERSION:-32.2.7}"

echo "[build-env] building $IMAGE (electron $ELECTRON_VERSION) ..."
docker build \
    --build-arg "ELECTRON_VERSION=$ELECTRON_VERSION" \
    --build-arg "UID=$(id -u)" \
    -t "$IMAGE" "$ROOT"

echo "[build-env] done: $IMAGE"
