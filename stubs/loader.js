/**
 * Interceptador de módulos nativos.
 *
 * O bundle chama require('.../native/<nome>.node'), que no Linux não existe
 * (os .node do app são Mach-O). Em vez de editar o bundle minificado, que
 * muda a cada release, nós substituímos o carregador de '.node' do Node:
 * qualquer require de um nativo do Granola devolve o stub JS correspondente
 * de stubs/modules/, e os demais .node (ex.: better-sqlite3 recompilado para
 * Linux) seguem o caminho normal.
 *
 * Uso: electron stubs/loader.js  (ele carrega o main real no fim)
 */
const path = require("path");
const fs = require("fs");
const Module = require("module");

const APP_DIR = process.env.GRANOLA_APP_DIR || path.join(__dirname, "..", "work", "app-src");
const STUB_DIR = path.join(__dirname, "modules");
const LINUX_NATIVE_DIR = process.env.GRANOLA_LINUX_NATIVE || "/opt/native-linux";
const VERBOSE = process.env.GRANOLA_STUB_VERBOSE !== "0";

const log = (...a) => VERBOSE && console.log("[stub]", ...a);

// Stubs disponíveis: nome do .node -> caminho do nosso JS
const stubs = new Map();
for (const f of fs.existsSync(STUB_DIR) ? fs.readdirSync(STUB_DIR) : []) {
  if (f.endsWith(".js")) stubs.set(path.basename(f, ".js"), path.join(STUB_DIR, f));
}
log(`${stubs.size} stubs carregados de ${STUB_DIR}`);

const originalNodeLoader = Module._extensions[".node"];

Module._extensions[".node"] = function (module, filename) {
  const name = path.basename(filename, ".node");
  if (stubs.has(name)) {
    log(`interceptado: ${name}`);
    module.exports = require(stubs.get(name));
    return;
  }
  // Nativos de terceiros recompilados para Linux (o bundle traz os de macOS).
  // Ex.: better_sqlite3, sem isto o require falha com "invalid ELF header"
  // e a UI não monta.
  const linuxBuild = path.join(LINUX_NATIVE_DIR, `${name}.node`);
  if (fs.existsSync(linuxBuild)) {
    log(`usando build Linux: ${name}`);
    return originalNodeLoader(module, linuxBuild);
  }
  try {
    return originalNodeLoader(module, filename);
  } catch (err) {
    // Nativo desconhecido e incompatível: não derruba o app, devolve objeto
    // vazio e registra, assim descobrimos o que ainda falta stubar.
    console.warn(`[stub] FALTA STUB: ${name} (${err.code || err.message})`);
    module.exports = new Proxy({}, {
      get: (_t, prop) => (typeof prop === "string" && prop !== "then"
        ? () => { throw new Error(`granola-linux: ${name}.${String(prop)}() não implementado`); }
        : undefined),
    });
  }
};

// O app resolve seus recursos (dist-app/index.html, assets do protocolo app://)
// a partir de process.resourcesPath, que no macOS é Granola.app/Contents/Resources.
// Rodando via `electron loader.js`, o Electron aponta isso para o diretório dele
// (/opt/electron/resources), onde não há nada: o renderer então falha com
// net::ERR_FAILED e a janela fica preta. Redirecionamos para o app extraído.
try {
  Object.defineProperty(process, "resourcesPath", {
    value: APP_DIR,
    writable: false,
    configurable: true,
  });
  log(`resourcesPath -> ${process.resourcesPath}`);
} catch (err) {
  console.warn("[stub] não foi possível ajustar resourcesPath:", err.message);
}

// app.getAppPath() devolve o diretório do "app" do Electron, que aqui é o do
// loader (/app/stubs), não o do Granola. O handler do protocolo app:// resolve
// os assets a partir dele, então todo request cai em caminho inexistente e
// volta net::ERR_FAILED. Apontamos para o app extraído.
try {
  const { app: electronApp } = require("electron");
  if (electronApp && typeof electronApp.getAppPath === "function") {
    electronApp.getAppPath = () => APP_DIR;
    log(`getAppPath -> ${APP_DIR}`);
  }
} catch (err) {
  log("não foi possível ajustar getAppPath:", err.message);
}

// Loga o caminho real que o handler tenta abrir (ele costuma usar net.fetch
// com file://). É o que revela se o problema é caminho errado ou permissão.
if (process.env.GRANOLA_TRACE_PROTOCOL !== "0") {
  try {
    const electron = require("electron");
    if (electron.net && typeof electron.net.fetch === "function") {
      const originalFetch = electron.net.fetch.bind(electron.net);
      let logged = 0;
      electron.net.fetch = async (input, init) => {
        const url = typeof input === "string" ? input : input && input.url;
        try {
          return await originalFetch(input, init);
        } catch (err) {
          if (logged++ < 5) console.warn(`[stub:fetch] ${url} -> ${err.message}`);
          throw err;
        }
      };
    }
  } catch (err) {
    log("não foi possível instrumentar net.fetch:", err.message);
  }
}

// Fallback do protocolo app://: lê o arquivo do disco e devolve um Response.
// app://ui/assets/x.js  ->  <APP_DIR>/dist-app/assets/x.js
const MIME = {
  ".js": "text/javascript", ".mjs": "text/javascript", ".css": "text/css",
  ".html": "text/html", ".json": "application/json", ".svg": "image/svg+xml",
  ".png": "image/png", ".jpg": "image/jpeg", ".jpeg": "image/jpeg",
  ".webp": "image/webp", ".gif": "image/gif", ".woff": "font/woff",
  ".woff2": "font/woff2", ".ttf": "font/ttf", ".mp3": "audio/mpeg",
  ".wav": "audio/wav", ".map": "application/json",
};

let servedCount = 0;

function serveFromDisk(request, why) {
  const url = new URL(request.url);
  // o host ('ui') é o subdiretório lógico; os arquivos vivem em dist-app/
  const rel = decodeURIComponent(url.pathname).replace(/^\/+/, "");
  const candidates = [
    path.join(APP_DIR, "dist-app", rel),
    path.join(APP_DIR, "dist-app", url.host || "", rel),
    path.join(APP_DIR, rel),
  ];
  for (const file of candidates) {
    // impede escapar do diretório do app
    if (!file.startsWith(APP_DIR)) continue;
    try {
      const body = fs.readFileSync(file);
      if (servedCount++ === 0) log(`servindo do disco (handler falhou: ${why})`);
      return new Response(body, {
        status: 200,
        headers: { "content-type": MIME[path.extname(file).toLowerCase()] || "application/octet-stream" },
      });
    } catch {
      /* tenta o próximo candidato */
    }
  }
  console.warn(`[stub:proto] não encontrado: ${request.url}`);
  return new Response("not found", { status: 404 });
}

// Instrumenta o registro do protocolo customizado (app://). A UI do Granola é
// servida por ele; se o handler resolver para um caminho inexistente, o
// renderer falha com net::ERR_FAILED e a janela fica preta, sem dizer qual
// arquivo faltou. Aqui logamos cada request e o que foi devolvido.
if (process.env.GRANOLA_TRACE_PROTOCOL !== "0") {
  try {
    const electron = require("electron");
    const { protocol } = electron;
    if (protocol && typeof protocol.handle === "function") {
      const originalHandle = protocol.handle.bind(protocol);
      protocol.handle = (scheme, handler) => {
        log(`protocol.handle registrado: ${scheme}://`);
        return originalHandle(scheme, async (request) => {
          try {
            const res = await handler(request);
            if (res && (!res.status || res.status < 400)) return res;
            return serveFromDisk(request, res && res.status);
          } catch (err) {
            // O handler do app usa net.fetch('file://…'), que o Chromium recusa
            // neste ambiente mesmo com o arquivo presente e legível. Servimos o
            // arquivo direto do disco, preservando o app intacto.
            return serveFromDisk(request, err.message);
          }
        });
      };
    }
  } catch (err) {
    log("não foi possível instrumentar protocol:", err.message);
  }
}

// Sobe o app real
const mainPath = path.join(APP_DIR, "dist-electron", "main", "index.js");
if (!fs.existsSync(mainPath)) {
  console.error(`[stub] ERRO: main não encontrado em ${mainPath}`);
  console.error("[stub] rode ./scripts/extract.sh antes");
  process.exit(1);
}
log(`carregando main: ${mainPath}`);
require(mainPath);
