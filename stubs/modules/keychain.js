/**
 * Stub de keychain.node (Keychain do macOS), guarda credenciais.
 *
 * Sem isto o login não persiste entre execuções. Implementação: arquivo local
 * com permissão 600 em ~/.config/granola-linux. NÃO é equivalente ao Keychain
 * (que é cifrado pelo SO); trocar por libsecret/gnome-keyring quando a Fase 1
 * provar que vale a pena.
 */
const fs = require("fs");
const os = require("os");
const path = require("path");

const DIR = path.join(os.homedir(), ".config", "granola-linux");
const FILE = path.join(DIR, "credentials.json");

function load() {
  try {
    return JSON.parse(fs.readFileSync(FILE, "utf8"));
  } catch {
    return {};
  }
}

function save(data) {
  fs.mkdirSync(DIR, { recursive: true, mode: 0o700 });
  fs.writeFileSync(FILE, JSON.stringify(data, null, 2), { mode: 0o600 });
}

const key = (service, account) => `${service || ""}:${account || ""}`;

module.exports = {
  getPassword(service, account) {
    return load()[key(service, account)] ?? null;
  },
  setPassword(service, account, password) {
    const db = load();
    db[key(service, account)] = password;
    save(db);
    return true;
  },
  deletePassword(service, account) {
    const db = load();
    delete db[key(service, account)];
    save(db);
    return true;
  },
  // aliases comuns em bindings de keychain
  findPassword(service) {
    const db = load();
    const hit = Object.keys(db).find((k) => k.startsWith(`${service}:`));
    return hit ? db[hit] : null;
  },
};
