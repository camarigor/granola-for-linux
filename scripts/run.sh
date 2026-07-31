#!/usr/bin/env bash
# Apply the stubs and launch the app inside the container, window on host X11.
# Nothing is installed on the host: Electron and Node live in the image.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="$ROOT/work"
APP="$WORK/app-src"
IMAGE="granola-for-linux:dev"

[[ -d "$APP" ]] || { echo "ERROR: run ./scripts/extract.sh first" >&2; exit 1; }
docker image inspect "$IMAGE" >/dev/null 2>&1 || { echo "ERROR: run ./scripts/build-env.sh first" >&2; exit 1; }

# The macOS native modules do not exist on Linux. Rather than editing the
# minified bundle (which changes every release), stubs/loader.js hooks Node's
# '.node' loader, injects our JS replacements, then loads the real main.

# ── X11 ──────────────────────────────────────────────────────────────────────
XSOCK=/tmp/.X11-unix
XAUTH_HOST="${XAUTHORITY:-$HOME/.Xauthority}"

# The loader's require hook only covers the main process; the renderer and the
# sqlite worker load .node files themselves. We shadow the macOS binary with the
# Linux build via bind-mount - the app on the host disk stays untouched.
NATIVE_DIR="$WORK/native-linux"
SQLITE_PKG="node_modules/better-sqlite3-multiple-ciphers"
# We shadow the WHOLE PACKAGE (JS + .node), not just the binary: the JS wrapper
# and the native addon share a per-version internal contract. Mixing the
# bundle's JS (12.9.0) with a newer .node breaks with
# "this[cppdb].updateHook is not a function".
# The image already built it with tables_used() enabled and the updateHook shim
# wired in (scripts/build-sqlite.sh); we only need a copy to mount.
if [[ ! -d "$NATIVE_DIR/better-sqlite3-multiple-ciphers" ]]; then
    echo "[run] extracting Linux sqlite build from the image ..."
    mkdir -p "$NATIVE_DIR"
    cid=$(docker create "$IMAGE")
    docker cp "$cid:/app/node_modules/better-sqlite3-multiple-ciphers" "$NATIVE_DIR/" >/dev/null
    docker rm "$cid" >/dev/null
fi

SQLITE_MOUNT=()
if [[ -d "$NATIVE_DIR/better-sqlite3-multiple-ciphers" && -d "$APP/$SQLITE_PKG" ]]; then
    SQLITE_MOUNT=(-v "$NATIVE_DIR/better-sqlite3-multiple-ciphers:/app/granola/$SQLITE_PKG:ro")
fi

# ── Persistent app data ──────────────────────────────────────────────────────
# Electron keeps userData under $XDG_CONFIG_HOME/<appName>; loader.js renames
# the app to Granola so it does not squat on the generic "Electron" directory.
# Without this volume the SQLite database and the auth tokens would live inside
# the container and every restart would force a fresh login.
DATA_DIR="$WORK/app-data"
mkdir -p "$DATA_DIR"
CONTAINER_DATA_DIR="/home/electron-cache/.config/Granola"

# ── URL bridge (container -> host browser) ───────────────────────────────────
# There is no browser inside the container, so the loader intercepts
# shell.openExternal and drops each URL as a file here; this watcher opens it
# on the host, where the user's real browser and sessions live. Login depends
# on this: the OAuth page must open in the host browser.
BRIDGE_DIR="$WORK/bridge"
mkdir -p "$BRIDGE_DIR"
rm -f "$BRIDGE_DIR"/open-*.url "$BRIDGE_DIR"/open-*.tmp
(
    while true; do
        for f in "$BRIDGE_DIR"/open-*.url; do
            [[ -e "$f" ]] || continue
            url=$(<"$f")
            rm -f "$f"
            echo "[bridge] opening on host: ${url:0:120}"
            xdg-open "$url" >/dev/null 2>&1 || echo "[bridge] xdg-open failed: $url"
        done
        sleep 0.5
    done
) &
BRIDGE_WATCHER=$!
trap 'kill "$BRIDGE_WATCHER" 2>/dev/null || true' EXIT

echo "[run] starting Electron in the container ..."
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
    -e GRANOLA_STUBS_DIR=/app/stubs \
    -e GRANOLA_BRIDGE_DIR=/app/bridge \
    -v "$BRIDGE_DIR:/app/bridge" \
    -v "$DATA_DIR:$CONTAINER_DATA_DIR" \
    -v "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/pulse:/run/pulse:ro" \
    -e PULSE_SERVER=unix:/run/pulse/native \
    -e XDG_RUNTIME_DIR=/run/user-host \
    -v "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}:/run/user-host:ro" \
    "${SQLITE_MOUNT[@]}" \
    --device /dev/dri \
    "$IMAGE" \
    -c "cd /app && exec /opt/electron/electron /app/stubs/loader.js --no-sandbox 2>&1"
