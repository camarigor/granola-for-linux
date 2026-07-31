#!/usr/bin/env bash
# Mapeia a superfície nativa do app: quais .node existem, contra quais
# frameworks Apple cada um linka, e quanta lógica por plataforma há no JS.
# Saída serve de insumo para docs/findings.md e para decidir o que stubar.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="$ROOT/work"
RES="$WORK/Granola/Granola.app/Contents/Resources"
MAIN="$WORK/app-src/dist-electron/main/index.js"

[[ -d "$RES" ]] || { echo "ERRO: rode ./scripts/extract.sh primeiro" >&2; exit 1; }

echo "=== MÓDULOS NATIVOS (.node) ==="
for n in "$RES"/native/*.node; do
    [[ -e "$n" ]] || continue
    fw=$(strings "$n" 2>/dev/null \
         | grep -oE 'ScreenCaptureKit|CoreAudio|AVFoundation|AVFAudio|EventKit|CoreMedia|AppKit' \
         | sort -u | paste -sd, -)
    printf "  %-38s %s\n" "$(basename "$n")" "${fw:-, }"
done

echo
echo "=== LÓGICA POR PLATAFORMA (main process) ==="
if [[ -f "$MAIN" ]]; then
    printf "  process.platform : %s ocorrências\n" "$(grep -oha 'process\.platform' "$MAIN" | wc -l)"
    for p in darwin win32 linux; do
        printf "  %-16s : %s\n" "$p" "$(grep -oha "$p" "$MAIN" | wc -l)"
    done
    echo "  caminhos native/ referenciados:"
    grep -ohaE 'native/[a-z_]+' "$MAIN" | sort -u | sed 's/^/    /'
else
    echo "  (main/index.js não encontrado)"
fi

echo
echo "=== MÓDULOS NATIVOS DE TERCEIROS (asar.unpacked) ==="
find "$RES/app.asar.unpacked/node_modules" -maxdepth 2 -name package.json 2>/dev/null \
    | while read -r p; do
        printf "  %s\n" "$(basename "$(dirname "$p")")"
      done | sort -u
