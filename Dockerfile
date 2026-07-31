# Ambiente de execução do Electron, TUDO fica no container.
# O host não recebe nenhuma instalação.
FROM node:22-slim

# Dependências de runtime do Electron/Chromium + áudio (PipeWire/Pulse via socket)
RUN apt-get update && apt-get install -y --no-install-recommends \
    libnss3 libatk1.0-0 libatk-bridge2.0-0 libcups2 libdrm2 libxkbcommon0 \
    libxcomposite1 libxdamage1 libxfixes3 libxrandr2 libgbm1 libasound2 \
    libpango-1.0-0 libcairo2 libgtk-3-0 libx11-xcb1 libxcb-dri3-0 \
    libpulse0 pulseaudio-utils python3 make g++ ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Electron na mesma major do bundle do Granola (ajustar após analyze.sh)
ARG ELECTRON_VERSION=32.2.7
RUN npm install --no-save electron@${ELECTRON_VERSION} @electron/asar \
    && npm cache clean --force

# Usuário não-root com o mesmo uid do host (evita root nos arquivos montados)
ARG UID=1000
RUN useradd -m -u ${UID} -s /bin/bash granola || true
USER granola

ENTRYPOINT ["/bin/bash"]
