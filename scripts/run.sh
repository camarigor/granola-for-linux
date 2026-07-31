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

# The loader's require hook only covers the main process; the renderer loads
# .node files on its own. We shadow the macOS binary with the Linux build via
# bind-mount - the app on the host disk stays untouched.
NATIVE_DIR="$WORK/native-linux"
SQLITE_PKG="node_modules/better-sqlite3-multiple-ciphers"
# We shadow the WHOLE PACKAGE (JS + .node), not just the binary: the JS wrapper
# and the native addon share a per-version internal contract. Mixing the
# bundle's JS (12.9.0) with a newer .node breaks with
# "this[cppdb].updateHook is not a function".
if [[ ! -d "$NATIVE_DIR/better-sqlite3-multiple-ciphers" ]]; then
    echo "[run] extracting Linux sqlite build from the image ..."
    mkdir -p "$NATIVE_DIR"
    cid=$(docker create "$IMAGE")
    docker cp "$cid:/app/node_modules/better-sqlite3-multiple-ciphers" "$NATIVE_DIR/" >/dev/null
    docker rm "$cid" >/dev/null

    # Granola ships a fork exposing db.updateHook(), absent from the public package.
    # We inject the method into OUR build (not the app) so startup can proceed.
    cat >> "$NATIVE_DIR/better-sqlite3-multiple-ciphers/lib/index.js" <<'SHIM'

// --- granola-for-linux: ver stubs/sqlite-updatehook-shim.js ---
try {
  require('/app/stubs/sqlite-updatehook-shim.js')(module.exports);
} catch (err) {
  console.warn('[granola-for-linux] updateHook shim not applied:', err.message);
}
SHIM
    echo "[run] updateHook shim applied to the local sqlite build"
fi

SQLITE_MOUNT=()
if [[ -d "$NATIVE_DIR/better-sqlite3-multiple-ciphers" && -d "$APP/$SQLITE_PKG" ]]; then
    SQLITE_MOUNT=(-v "$NATIVE_DIR/better-sqlite3-multiple-ciphers:/app/granola/$SQLITE_PKG:ro")
fi

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
    -v "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/pulse:/run/pulse:ro" \
    -e PULSE_SERVER=unix:/run/pulse/native \
    "${SQLITE_MOUNT[@]}" \
    --device /dev/dri \
    "$IMAGE" \
    -c "cd /app && exec /opt/electron/electron /app/stubs/loader.js --no-sandbox 2>&1"
