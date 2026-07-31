#!/usr/bin/env bash
# Constrói o .deb DENTRO de um container, nada é instalado no host.
#
# O pacote leva: Electron (baixado aqui), nossos stubs e o launcher.
# NÃO leva nada do Granola: o app é extraído do .dmg do próprio usuário na
# primeira execução.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="${VERSION:-0.1.0}"
ELECTRON_VERSION="${ELECTRON_VERSION:-32.2.7}"
OUT="$ROOT/dist"

mkdir -p "$OUT"

docker run --rm \
    -e VERSION="$VERSION" -e ELECTRON_VERSION="$ELECTRON_VERSION" -e UID="$(id -u)" \
    -v "$ROOT:/src:ro" -v "$OUT:/out" \
    node:22-slim bash -euo pipefail -c '
apt-get update -qq && apt-get install -y -qq --no-install-recommends \
    unzip curl dpkg-dev fakeroot >/dev/null

PKG=/tmp/pkg
PREFIX=$PKG/opt/granola-linux
mkdir -p "$PREFIX"/{stubs,bin} "$PKG/DEBIAN" "$PKG/usr/bin" "$PKG/usr/share/applications"

echo "[deb] baixando electron ${ELECTRON_VERSION} ..."
curl -fsSL -o /tmp/electron.zip \
  "https://github.com/electron/electron/releases/download/v${ELECTRON_VERSION}/electron-v${ELECTRON_VERSION}-linux-x64.zip"
mkdir -p "$PREFIX/electron" && unzip -q /tmp/electron.zip -d "$PREFIX/electron"
chmod +x "$PREFIX/electron/electron"

echo "[deb] instalando asar (para extrair o app.asar do usuário) ..."
npm install --no-save --silent --prefix "$PREFIX/bin" @electron/asar >/dev/null
cat > "$PREFIX/bin/asar-extract" <<EOS
#!/bin/sh
exec "$PREFIX/bin/node_modules/.bin/asar" extract "\$1" "\$2"
EOS
chmod +x "$PREFIX/bin/asar-extract"

cp -r /src/stubs/. "$PREFIX/stubs/"
install -m 755 /src/packaging/granola-linux "$PKG/usr/bin/granola-linux"
install -m 644 /src/packaging/granola-linux.desktop "$PKG/usr/share/applications/"
install -m 644 /src/packaging/debian-control "$PKG/DEBIAN/control"
sed -i "s/^Version:.*/Version: ${VERSION}/" "$PKG/DEBIAN/control"

SIZE=$(du -sk "$PKG" | cut -f1)
echo "Installed-Size: ${SIZE}" >> "$PKG/DEBIAN/control"

echo "[deb] empacotando ..."
fakeroot dpkg-deb --build "$PKG" "/out/granola-linux_${VERSION}_amd64.deb" >/dev/null
chown "${UID}:${UID}" "/out/granola-linux_${VERSION}_amd64.deb"
'

echo
ls -lh "$OUT"/*.deb
echo
echo "instalar:  sudo apt install $OUT/granola-linux_${VERSION}_amd64.deb"
echo "usar:      granola-linux ~/Downloads/'Granola - AI Notepad.dmg'   (só na 1a vez)"
