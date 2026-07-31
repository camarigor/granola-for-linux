# Electron runtime environment - everything lives in the container.
# Nothing is installed on the host.
FROM node:22-slim

# Electron/Chromium runtime deps + audio (PipeWire/Pulse over socket)
RUN apt-get update && apt-get install -y --no-install-recommends \
    libnss3 libatk1.0-0 libatk-bridge2.0-0 libcups2 libdrm2 libxkbcommon0 \
    libxcomposite1 libxdamage1 libxfixes3 libxrandr2 libgbm1 libasound2 \
    libpango-1.0-0 libcairo2 libgtk-3-0 libx11-xcb1 libxcb-dri3-0 \
    libpulse0 pulseaudio-utils python3 make g++ ca-certificates \
    # GL/EGL: without these Chromium's GPU process dies with
    # "Could not dlopen libGL.so.1" and the window renders black
    libgl1 libglx-mesa0 libegl1 libgles2 libglapi-mesa libgl1-mesa-dri \
    dbus-x11 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# better-sqlite3-multiple-ciphers ships as a macOS build (Mach-O) in the bundle;
# on Linux require fails with "invalid ELF header" and the UI never mounts. We build
# it against the Electron headers; the loader redirects the require.
ARG SQLITE_PKG_VERSION=12.11.1
ARG ELECTRON_VERSION_FOR_ABI=42.7.0
# Install with --ignore-scripts (download only), patch SQLite's compile-time
# options, then compile once with node-gyp called directly, its CLI flags DO
# reach the build (npm install is what fails to forward them).
#
# SQLITE_ENABLE_BYTECODE_VTAB: Granola's cacheStore queries tables_used(), a
# SQLite table-valued function that only exists under this flag. Their private
# sqlite fork enables it; the public package does not, and without it startup
# dies with "sqlite-exec-error: no such table: tables_used". The grep fails
# the build early if a future package version moves the sed anchor.
RUN npm install --no-save --ignore-scripts \
        better-sqlite3-multiple-ciphers@${SQLITE_PKG_VERSION} node-gyp \
    && sed -i "/'SQLITE_ENABLE_DBSTAT_VTAB',/a\\    'SQLITE_ENABLE_BYTECODE_VTAB'," \
        node_modules/better-sqlite3-multiple-ciphers/deps/defines.gypi \
    && grep -q SQLITE_ENABLE_BYTECODE_VTAB \
        node_modules/better-sqlite3-multiple-ciphers/deps/defines.gypi \
    && cd node_modules/better-sqlite3-multiple-ciphers \
    && ../.bin/node-gyp rebuild \
        --runtime=electron --target=${ELECTRON_VERSION_FOR_ABI} \
        --dist-url=https://electronjs.org/headers --arch=x64 \
    && cd /app \
    && mkdir -p /opt/native-linux \
    && cp node_modules/better-sqlite3-multiple-ciphers/build/Release/better_sqlite3.node \
          /opt/native-linux/ \
    && test -f /opt/native-linux/better_sqlite3.node

# Electron pinned to the same version as the Granola bundle (read from the
# Electron Framework Info.plist inside the .dmg - see docs/findings.md).
# The binary is fetched at build time: at runtime the container has no write
# permission on /app, so a late download would fail.
ARG ELECTRON_VERSION=42.7.0
RUN apt-get update && apt-get install -y --no-install-recommends curl unzip \
    && curl -fsSL -o /tmp/electron.zip \
        "https://github.com/electron/electron/releases/download/v${ELECTRON_VERSION}/electron-v${ELECTRON_VERSION}-linux-x64.zip" \
    && mkdir -p /opt/electron && unzip -q /tmp/electron.zip -d /opt/electron \
    && chmod +x /opt/electron/electron && rm /tmp/electron.zip \
    && test -x /opt/electron/electron \
    && apt-get purge -y unzip && apt-get autoremove -y && rm -rf /var/lib/apt/lists/*

# Run as the host uid so mounted volumes do not end up root-owned.
# The node image already uses uid 1000 ('node'); only create a user if free.
ARG UID=1000
RUN if ! id -u ${UID} >/dev/null 2>&1; then \
        useradd -m -u ${UID} -s /bin/bash granola; \
    fi \
    && mkdir -p /home/electron-cache && chown ${UID} /home/electron-cache
ENV HOME=/home/electron-cache XDG_CONFIG_HOME=/home/electron-cache/.config
USER ${UID}

ENTRYPOINT ["/bin/bash"]
