#!/usr/bin/env bash
# Map the app's native surface: which .node files exist, which Apple
# frameworks each links against, and how much platform logic the JS has.
# Feeds docs/findings.md and the decision of what to stub.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="$ROOT/work"
RES="$WORK/Granola/Granola.app/Contents/Resources"
MAIN="$WORK/app-src/dist-electron/main/index.js"

[[ -d "$RES" ]] || { echo "ERROR: run ./scripts/extract.sh first" >&2; exit 1; }

echo "=== NATIVE MODULES (.node) ==="
for n in "$RES"/native/*.node; do
    [[ -e "$n" ]] || continue
    fw=$(strings "$n" 2>/dev/null \
         | grep -oE 'ScreenCaptureKit|CoreAudio|AVFoundation|AVFAudio|EventKit|CoreMedia|AppKit' \
         | sort -u | paste -sd, -)
    printf "  %-38s %s\n" "$(basename "$n")" "${fw:-}"
done

echo
echo "=== PLATFORM LOGIC (main process) ==="
if [[ -f "$MAIN" ]]; then
    printf "  process.platform : %s occurrences\n" "$(grep -oha 'process\.platform' "$MAIN" | wc -l)"
    for p in darwin win32 linux; do
        printf "  %-16s : %s\n" "$p" "$(grep -oha "$p" "$MAIN" | wc -l)"
    done
    echo "  native/ paths referenced:"
    grep -ohaE 'native/[a-z_]+' "$MAIN" | sort -u | sed 's/^/    /'
else
    echo "  (main/index.js not found)"
fi

echo
echo "=== THIRD-PARTY NATIVE MODULES (asar.unpacked) ==="
find "$RES/app.asar.unpacked/node_modules" -maxdepth 2 -name package.json 2>/dev/null \
    | while read -r p; do
        printf "  %s\n" "$(basename "$(dirname "$p")")"
      done | sort -u
