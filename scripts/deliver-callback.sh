#!/usr/bin/env bash
# Deliver a granola:// OAuth callback URL into the running container.
#
# After login in the host browser, the backend redirects to a granola://...
# deep link. The host has no handler for that scheme, so the browser shows an
# error. Copy that URL and pass it here; the loader's bridge watcher picks up
# the callback-*.url file and re-emits it as the app's 'open-url' event.
#
# Usage:  ./scripts/deliver-callback.sh 'granola://...'
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BRIDGE_DIR="$ROOT/work/bridge"

url="${1:-}"
if [[ -z "$url" ]]; then
    echo "usage: $0 'granola://login-complete?...'  |  '<app-redirect URL>'" >&2
    exit 1
fi

# Accept the granola.ai/app-redirect URL straight from the browser address bar
# and convert it: the app routes on the deep link's *hostname*, and
# 'login-complete' is one of its allowed actions (see docs/findings.md).
if [[ "$url" == http*://*granola.ai/app-redirect\?* ]]; then
    url="granola://login-complete?${url#*\?}"
    echo "[deliver] converted app-redirect URL to deep link"
elif [[ "$url" != granola://* && "$url" != granola-dev://* ]]; then
    echo "warning: expected granola:// or an app-redirect URL, got: ${url:0:40}..." >&2
fi

mkdir -p "$BRIDGE_DIR"
# Two-step write so the in-container watcher never reads a half-written file.
tmp="$BRIDGE_DIR/callback-$$.tmp"
final="$BRIDGE_DIR/callback-$$.url"
printf '%s' "$url" > "$tmp"
mv "$tmp" "$final"
echo "[deliver] queued callback for the app: ${url:0:60}..."
