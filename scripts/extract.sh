#!/usr/bin/env bash
# Extract the official Granola .dmg into work/ (never versioned).
# Uses the host's 7z - the only requirement outside the container.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="$ROOT/work"
DMG="${1:-}"

if [[ -z "$DMG" || ! -f "$DMG" ]]; then
    echo "usage: $0 <path to Granola.dmg>" >&2
    exit 1
fi

command -v 7z >/dev/null || { echo "ERROR: 7z not found (apt install p7zip-full)" >&2; exit 1; }

mkdir -p "$WORK"
echo "[extract] reading $(basename "$DMG") ..."
7z x -y -o"$WORK" "$DMG" 'Granola/Granola.app/Contents/Resources/*' >/dev/null

RES="$WORK/Granola/Granola.app/Contents/Resources"
[[ -f "$RES/app.asar" ]] || { echo "ERROR: app.asar not found in $RES" >&2; exit 1; }

echo "[extract] unpacking app.asar ..."
rm -rf "$WORK/app-src"
# @electron/asar runs inside the container so nothing is installed on the host
docker run --rm \
    -v "$WORK:/work" -w /work \
    node:22-slim \
    npx --yes @electron/asar extract \
        Granola/Granola.app/Contents/Resources/app.asar app-src >/dev/null

VERSION=$(python3 -c "import json;print(json.load(open('$WORK/app-src/package.json'))['version'])" 2>/dev/null || echo '?')
NATIVE_COUNT=$(ls "$RES/native/"*.node 2>/dev/null | wc -l)

echo "[extract] done."
echo "  app version    : $VERSION"
echo "  native modules : $NATIVE_COUNT (macOS, Mach-O)"
echo "  JS source      : $WORK/app-src"
