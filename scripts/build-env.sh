#!/usr/bin/env bash
# Constrói a imagem com Electron. Nada é instalado no host.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IMAGE="granola-linux:dev"

# A major do Electron precisa bater com a do bundle; analyze.sh ajuda a
# descobrir. Sobrescreva com: ELECTRON_VERSION=31.7.7 ./scripts/build-env.sh
ELECTRON_VERSION="${ELECTRON_VERSION:-32.2.7}"

echo "[build-env] construindo $IMAGE (electron $ELECTRON_VERSION) ..."
docker build \
    --build-arg "ELECTRON_VERSION=$ELECTRON_VERSION" \
    --build-arg "UID=$(id -u)" \
    -t "$IMAGE" "$ROOT"

echo "[build-env] pronto: $IMAGE"
