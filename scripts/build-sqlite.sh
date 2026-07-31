#!/usr/bin/env bash
# Build better-sqlite3-multiple-ciphers for Linux, against Electron's ABI and
# with the compile-time option Granola's private fork relies on.
#
# Single source of truth for both delivery paths: the dev container (Dockerfile)
# and the .deb (packaging/build-deb.sh). The recipe is subtle enough that having
# two copies would guarantee they drift.
#
# Usage: build-sqlite.sh <destination-dir>
#   Leaves <destination-dir>/better-sqlite3-multiple-ciphers ready to use.
#
# Env:
#   SQLITE_PKG_VERSION        package version to build (default 12.11.1)
#   ELECTRON_VERSION_FOR_ABI  Electron release whose headers to compile against
set -euo pipefail

DEST="${1:?usage: build-sqlite.sh <destination-dir>}"
PKG="better-sqlite3-multiple-ciphers"
PKG_VERSION="${SQLITE_PKG_VERSION:-12.11.1}"
ABI="${ELECTRON_VERSION_FOR_ABI:?ELECTRON_VERSION_FOR_ABI is required}"

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

echo "[sqlite] fetching ${PKG}@${PKG_VERSION} ..."
# --ignore-scripts: download only. We compile explicitly below, because
# `npm install --runtime=electron --target=...` does NOT forward those flags to
# node-gyp; calling node-gyp directly does.
(cd "$WORKDIR" && npm install --no-save --silent --ignore-scripts "${PKG}@${PKG_VERSION}" node-gyp >/dev/null)

SRC="$WORKDIR/node_modules/$PKG"

# Granola's cacheStore queries tables_used(), a SQLite table-valued function
# that only exists under SQLITE_ENABLE_BYTECODE_VTAB. Their fork enables it, the
# public package does not, and without it the app dies at startup with
# "sqlite-exec-error: no such table: tables_used". The grep makes the build fail
# loudly if a future package version moves the anchor, instead of silently
# producing a binary that is missing the function.
echo "[sqlite] enabling SQLITE_ENABLE_BYTECODE_VTAB ..."
sed -i "/'SQLITE_ENABLE_DBSTAT_VTAB',/a\\    'SQLITE_ENABLE_BYTECODE_VTAB'," "$SRC/deps/defines.gypi"
grep -q SQLITE_ENABLE_BYTECODE_VTAB "$SRC/deps/defines.gypi"

echo "[sqlite] compiling against Electron ${ABI} headers ..."
(cd "$SRC" && "$WORKDIR/node_modules/.bin/node-gyp" rebuild \
    --runtime=electron --target="$ABI" \
    --dist-url=https://electronjs.org/headers --arch=x64 >/dev/null)
test -f "$SRC/build/Release/better_sqlite3.node"

# The other half of the fork: db.updateHook(). It is the app's change
# notification backbone, so it has to be a real implementation, not a stub: see
# stubs/sqlite-updatehook-shim.js. The require has to live inside the package
# itself: the sqlite worker runs in its own thread and never passes through the
# loader's require hook. GRANOLA_STUBS_DIR keeps the one snippet working from
# both the container (/app/stubs) and the .deb (/opt/granola-for-linux/stubs).
echo "[sqlite] wiring the updateHook shim ..."
cat >> "$SRC/lib/index.js" <<'SHIM'

// --- granola-for-linux: see stubs/sqlite-updatehook-shim.js ---
try {
  const dir = process.env.GRANOLA_STUBS_DIR || "/app/stubs";
  require(require("path").join(dir, "sqlite-updatehook-shim.js"))(module.exports);
} catch (err) {
  console.warn("[granola-for-linux] updateHook shim not applied:", err.message);
}
SHIM

mkdir -p "$DEST"
rm -rf "${DEST:?}/$PKG"
cp -r "$SRC" "$DEST/$PKG"
echo "[sqlite] ready: $DEST/$PKG"
