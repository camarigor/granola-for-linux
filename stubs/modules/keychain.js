/**
 * Stub for keychain.node (macOS Keychain) - credential storage.
 *
 * Without it the login does not survive a restart. Implementation: a local
 * 600-mode file under ~/.config/granola-for-linux. This is NOT equivalent to the
 * Keychain (OS-encrypted); swap for libsecret/gnome-keyring once Phase 1
 * proves it is worth it.
 */
const fs = require("fs");
const os = require("os");
const path = require("path");

const DIR = path.join(os.homedir(), ".config", "granola-for-linux");
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
  // aliases commonly found in keychain bindings
  findPassword(service) {
    const db = load();
    const hit = Object.keys(db).find((k) => k.startsWith(`${service}:`));
    return hit ? db[hit] : null;
  },
};
