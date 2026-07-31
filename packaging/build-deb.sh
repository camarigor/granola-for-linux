#!/usr/bin/env bash
# Build the .deb INSIDE a container - nothing is installed on the host.
#
# The package ships: Electron (fetched here), our stubs and the launcher.
# It ships NOTHING from Granola: the app is extracted from the user's own .dmg
# on first run.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="${VERSION:-0.1.0}"
# Must match the Electron the Granola bundle was built for: the native SQLite
# module is compiled against this ABI, and the app's own code assumes it.
ELECTRON_VERSION="${ELECTRON_VERSION:-42.7.0}"
OUT="$ROOT/dist"

mkdir -p "$OUT"

docker run --rm \
    -e VERSION="$VERSION" -e ELECTRON_VERSION="$ELECTRON_VERSION" -e UID="$(id -u)" \
    -v "$ROOT:/src:ro" -v "$OUT:/out" \
    node:22-slim bash -euo pipefail -c '
apt-get update -qq && apt-get install -y -qq --no-install-recommends \
    ca-certificates unzip curl dpkg-dev fakeroot python3 make g++ >/dev/null
# Without apt-utils the postinst scripts are deferred, so ca-certificates never
# generates its bundle and every https fetch dies with
# "curl: (77) error setting certificate file". Generate it explicitly.
update-ca-certificates >/dev/null 2>&1 || true

PKG=/tmp/pkg
PREFIX=$PKG/opt/granola-for-linux
mkdir -p "$PREFIX"/{stubs,bin,native} "$PKG/DEBIAN" "$PKG/usr/bin" "$PKG/usr/share/applications"

echo "[deb] downloading electron ${ELECTRON_VERSION} ..."
curl -fsSL -o /tmp/electron.zip \
  "https://github.com/electron/electron/releases/download/v${ELECTRON_VERSION}/electron-v${ELECTRON_VERSION}-linux-x64.zip"
mkdir -p "$PREFIX/electron" && unzip -q /tmp/electron.zip -d "$PREFIX/electron"
chmod +x "$PREFIX/electron/electron"

# The bundle ships a macOS (Mach-O) better-sqlite3-multiple-ciphers, and the
# public package is missing two features Granola'"'"'s private fork provides. Same
# recipe as the dev container - see scripts/build-sqlite.sh.
echo "[deb] building the Linux sqlite module ..."
ELECTRON_VERSION_FOR_ABI="${ELECTRON_VERSION}" bash /src/scripts/build-sqlite.sh "$PREFIX/native"

echo "[deb] installing asar (to unpack the user app.asar) ..."
npm install --no-save --silent --prefix "$PREFIX/bin" @electron/asar >/dev/null
# Quoted heredoc: the paths below must resolve where the package is INSTALLED,
# not where it is being staged. An unquoted one bakes in /tmp/pkg/... and the
# script dies with "not found" on the user machine.
# asar ships a #!/usr/bin/env node script, and a .deb has no business requiring
# Node on the host, so it runs through the Electron we already ship.
cat > "$PREFIX/bin/asar-extract" <<"EOS"
#!/bin/sh
INSTALL_PREFIX=/opt/granola-for-linux
export ELECTRON_RUN_AS_NODE=1
exec "$INSTALL_PREFIX/electron/electron" \
    "$INSTALL_PREFIX/bin/node_modules/@electron/asar/bin/asar.mjs" \
    extract "$1" "$2"
EOS
chmod +x "$PREFIX/bin/asar-extract"

cp -r /src/stubs/. "$PREFIX/stubs/"
install -m 755 /src/packaging/granola-for-linux "$PKG/usr/bin/granola-for-linux"
install -m 644 /src/packaging/granola-for-linux.desktop "$PKG/usr/share/applications/"
install -m 644 /src/packaging/debian-control "$PKG/DEBIAN/control"
install -m 755 /src/packaging/debian-postinst "$PKG/DEBIAN/postinst"
install -m 755 /src/packaging/debian-postrm "$PKG/DEBIAN/postrm"
sed -i "s/^Version:.*/Version: ${VERSION}/" "$PKG/DEBIAN/control"

# Installed-Size counts the unpacked payload only, and is in KiB.
SIZE=$(du -sk --exclude=DEBIAN "$PKG" | cut -f1)
echo "Installed-Size: ${SIZE}" >> "$PKG/DEBIAN/control"

echo "[deb] packaging ..."
fakeroot dpkg-deb --build "$PKG" "/out/granola-for-linux_${VERSION}_amd64.deb" >/dev/null

echo "[deb] checking the result ..."
dpkg-deb --info "/out/granola-for-linux_${VERSION}_amd64.deb" | sed -n "1,40p"
# lintian is not available here, but dpkg-deb parsing the control file is
# already enough to catch a malformed Depends line or a broken description.
chown "${UID}:${UID}" "/out/granola-for-linux_${VERSION}_amd64.deb"
'

DEB="$OUT/granola-for-linux_${VERSION}_amd64.deb"

# apt fetches as the unprivileged '_apt' user. If any directory on the way to
# the package is not world-traversable: a home directory is usually 750, apt
# cannot read it, prints "Download is performed unsandboxed as root" and falls
# back to root. It installs correctly either way, but suggesting a path apt can
# actually reach keeps the output clean.
apt_can_read() {
    local dir="$1"
    while [[ "$dir" != "/" ]]; do
        # Last character of the mode string is other-execute: 'x', or 't' when
        # the sticky bit is set (as on /tmp). Both mean traversable.
        [[ "$(stat -c '%A' "$dir" 2>/dev/null)" == *[xt] ]] || return 1
        dir="$(dirname "$dir")"
    done
    return 0
}

echo
ls -lh "$DEB"
echo
if apt_can_read "$OUT"; then
    echo "install:  sudo apt install $DEB"
else
    echo "install:  cp $DEB /tmp/ && sudo apt install /tmp/$(basename "$DEB")"
    echo "          (installing straight from \$HOME works too, but apt warns that"
    echo "           its '_apt' user cannot read through a 750 home directory)"
fi
echo "use:      granola-for-linux ~/Downloads/'Granola - AI Notepad.dmg'"
echo "          (installs Granola from your own .dmg; pass a newer one to update)"
echo "then:     granola-for-linux"
