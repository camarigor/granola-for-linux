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
# npm does not reliably forward --runtime/--target to node-gyp; the
# npm_config_* environment variables are what actually works (otherwise it
# builds against Node headers and breaks on the V8 API).
RUN npm_config_runtime=electron \
    npm_config_target=${ELECTRON_VERSION_FOR_ABI} \
    npm_config_disturl=https://electronjs.org/headers \
    npm_config_build_from_source=true \
    npm_config_arch=x64 \
    npm install --no-save \
        better-sqlite3-multiple-ciphers@${SQLITE_PKG_VERSION} \
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
