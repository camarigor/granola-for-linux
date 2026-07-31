#!/usr/bin/env bash
# Aplica os stubs e sobe o app dentro do container, com a janela no X11 do host.
# O host não instala nada: Electron e Node vivem na imagem.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="$ROOT/work"
APP="$WORK/app-src"
IMAGE="granola-linux:dev"

[[ -d "$APP" ]] || { echo "ERRO: rode ./scripts/extract.sh primeiro" >&2; exit 1; }
docker image inspect "$IMAGE" >/dev/null 2>&1 || { echo "ERRO: rode ./scripts/build-env.sh primeiro" >&2; exit 1; }

# Os módulos nativos macOS não existem no Linux. Em vez de editar o bundle
# minificado (que muda a cada release), stubs/loader.js intercepta o carregador
# de '.node' do Node e injeta nossos substitutos JS, depois sobe o main real.

# ── X11 ──────────────────────────────────────────────────────────────────────
XSOCK=/tmp/.X11-unix
XAUTH_HOST="${XAUTHORITY:-$HOME/.Xauthority}"

# O hook de require do loader só vale no processo principal; o renderer carrega
# os .node por conta própria. Sobrepomos o binário macOS pelo build Linux via
# bind-mount, o app no disco do host continua intacto.
NATIVE_DIR="$WORK/native-linux"
SQLITE_REL="node_modules/better-sqlite3-multiple-ciphers/build/Release/better_sqlite3.node"
if [[ ! -f "$NATIVE_DIR/better_sqlite3.node" ]]; then
    echo "[run] extraindo build Linux do sqlite da imagem ..."
    mkdir -p "$NATIVE_DIR"
    cid=$(docker create "$IMAGE")
    docker cp "$cid:/opt/native-linux/better_sqlite3.node" "$NATIVE_DIR/" >/dev/null
    docker rm "$cid" >/dev/null
fi

SQLITE_MOUNT=()
if [[ -f "$NATIVE_DIR/better_sqlite3.node" && -f "$APP/$SQLITE_REL" ]]; then
    SQLITE_MOUNT=(-v "$NATIVE_DIR/better_sqlite3.node:/app/granola/$SQLITE_REL:ro")
fi

echo "[run] subindo Electron no container ..."
docker run --rm ${DOCKER_TTY:--it} \
    -e DISPLAY="${DISPLAY:-:0}" \
    -e XAUTHORITY=/tmp/.docker.xauth \
    -e ELECTRON_ENABLE_LOGGING=1 \
    -e ELECTRON_DISABLE_SECURITY_WARNINGS=1 \
    -v "$XSOCK:$XSOCK:ro" \
    -v "$XAUTH_HOST:/tmp/.docker.xauth:ro" \
    -e GRANOLA_APP_DIR=/app/granola \
    -v "$APP:/app/granola" \
    -v "$ROOT/stubs:/app/stubs:ro" \
    -v "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/pulse:/run/pulse:ro" \
    -e PULSE_SERVER=unix:/run/pulse/native \
    "${SQLITE_MOUNT[@]}" \
    --device /dev/dri \
    "$IMAGE" \
    -c "cd /app && exec /opt/electron/electron /app/stubs/loader.js --no-sandbox 2>&1"
