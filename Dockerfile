# Ambiente de execução do Electron, TUDO fica no container.
# O host não recebe nenhuma instalação.
FROM node:22-slim

# Dependências de runtime do Electron/Chromium + áudio (PipeWire/Pulse via socket)
RUN apt-get update && apt-get install -y --no-install-recommends \
    libnss3 libatk1.0-0 libatk-bridge2.0-0 libcups2 libdrm2 libxkbcommon0 \
    libxcomposite1 libxdamage1 libxfixes3 libxrandr2 libgbm1 libasound2 \
    libpango-1.0-0 libcairo2 libgtk-3-0 libx11-xcb1 libxcb-dri3-0 \
    libpulse0 pulseaudio-utils python3 make g++ ca-certificates \
    # GL/EGL: sem isto o processo de GPU do Chromium morre em
    # "Could not dlopen libGL.so.1" e a janela abre preta
    libgl1 libglx-mesa0 libegl1 libgles2 libglapi-mesa libgl1-mesa-dri \
    dbus-x11 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# better-sqlite3-multiple-ciphers vem compilado para macOS no bundle (Mach-O);
# no Linux o require falha com "invalid ELF header" e a UI não monta. Compilamos
# a MESMA versão contra os headers do Electron; o loader redireciona o require.
ARG SQLITE_PKG_VERSION=12.11.1
ARG ELECTRON_VERSION_FOR_ABI=42.7.0
# npm não repassa --runtime/--target ao node-gyp de forma confiável; as
# variáveis npm_config_* são o caminho que funciona (senão compila contra os
# headers do Node e quebra na API do V8).
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

# Electron na MESMA versão do bundle do Granola (lida do Info.plist do
# Electron Framework dentro do .dmg, ver docs/findings.md).
# O binário é baixado no build: em runtime o container roda sem permissão de
# escrita em /app, então um download tardio falharia.
ARG ELECTRON_VERSION=42.7.0
RUN apt-get update && apt-get install -y --no-install-recommends curl unzip \
    && curl -fsSL -o /tmp/electron.zip \
        "https://github.com/electron/electron/releases/download/v${ELECTRON_VERSION}/electron-v${ELECTRON_VERSION}-linux-x64.zip" \
    && mkdir -p /opt/electron && unzip -q /tmp/electron.zip -d /opt/electron \
    && chmod +x /opt/electron/electron && rm /tmp/electron.zip \
    && test -x /opt/electron/electron \
    && apt-get purge -y unzip && apt-get autoremove -y && rm -rf /var/lib/apt/lists/*

# Roda com o mesmo uid do host (evita arquivos root nos volumes montados).
# A imagem node já usa o uid 1000 ('node'); só criamos usuário se estiver livre.
ARG UID=1000
RUN if ! id -u ${UID} >/dev/null 2>&1; then \
        useradd -m -u ${UID} -s /bin/bash granola; \
    fi \
    && mkdir -p /home/electron-cache && chown ${UID} /home/electron-cache
ENV HOME=/home/electron-cache XDG_CONFIG_HOME=/home/electron-cache/.config
USER ${UID}

ENTRYPOINT ["/bin/bash"]
