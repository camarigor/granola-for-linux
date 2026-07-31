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

// Sobe o app real
const mainPath = path.join(APP_DIR, "dist-electron", "main", "index.js");
if (!fs.existsSync(mainPath)) {
  console.error(`[stub] ERRO: main não encontrado em ${mainPath}`);
  console.error("[stub] rode ./scripts/extract.sh antes");
  process.exit(1);
}
log(`carregando main: ${mainPath}`);
require(mainPath);
