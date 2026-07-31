#!/usr/bin/env bash
# Extrai o .dmg oficial do Granola para work/ (nada é versionado).
# Usa 7z do host, o único requisito fora do container.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="$ROOT/work"
DMG="${1:-}"

if [[ -z "$DMG" || ! -f "$DMG" ]]; then
    echo "uso: $0 <caminho para o Granola.dmg>" >&2
    exit 1
fi

command -v 7z >/dev/null || { echo "ERRO: 7z não encontrado (apt install p7zip-full)" >&2; exit 1; }

mkdir -p "$WORK"
echo "[extract] lendo $(basename "$DMG") ..."
7z x -y -o"$WORK" "$DMG" 'Granola/Granola.app/Contents/Resources/*' >/dev/null

RES="$WORK/Granola/Granola.app/Contents/Resources"
[[ -f "$RES/app.asar" ]] || { echo "ERRO: app.asar não encontrado em $RES" >&2; exit 1; }

echo "[extract] desempacotando app.asar ..."
rm -rf "$WORK/app-src"
# @electron/asar roda dentro do container para não instalar nada no host
docker run --rm \
    -v "$WORK:/work" -w /work \
    node:22-slim \
    npx --yes @electron/asar extract \
        Granola/Granola.app/Contents/Resources/app.asar app-src >/dev/null

VERSION=$(python3 -c "import json;print(json.load(open('$WORK/app-src/package.json'))['version'])" 2>/dev/null || echo '?')
NATIVE_COUNT=$(ls "$RES/native/"*.node 2>/dev/null | wc -l)

echo "[extract] pronto."
echo "  versão do app : $VERSION"
echo "  módulos nativos: $NATIVE_COUNT (macOS, Mach-O)"
echo "  código JS      : $WORK/app-src"
