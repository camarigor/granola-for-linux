/**
 * Stub for keychain.node (macOS Keychain) - credential storage.
 *
 * Observed on Linux: the app never loads this module. It keeps its own tokens
 * in userData (stored-accounts.json.enc and supabase.json.enc, encrypted with
 * storage.dek), which is why signing in survives a restart without the
 * keychain being involved at all. The stub stays because the module is present
 * in the macOS bundle and some code path may still reach for it.
 *
 * If it is ever called, the file belongs in userData: that is the directory
 * both delivery paths persist, whereas a directory of its own would be
 * container-ephemeral. A 600-mode JSON file is NOT equivalent to the Keychain
 * (OS-encrypted); swap for libsecret/gnome-keyring if this ever carries real
 * secrets.
 */
const fs = require("fs");
const os = require("os");
const path = require("path");

function credentialsDir() {
  try {
    const { app } = require("electron");
    if (app && typeof app.getPath === "function") return app.getPath("userData");
  } catch {
    // not the main process (or Electron unavailable), fall through
  }
  return process.env.GRANOLA_CREDENTIALS_DIR
    || path.join(os.homedir(), ".config", "granola-for-linux");
}

const DIR = credentialsDir();
const FILE = path.join(DIR, "credentials.json");
// Where earlier builds wrote; read it if the current location has nothing, so
// changing the path never silently drops a stored credential.
const LEGACY_FILE = path.join(os.homedir(), ".config", "granola-for-linux", "credentials.json");

function load() {
  for (const file of [FILE, LEGACY_FILE]) {
    try {
      return JSON.parse(fs.readFileSync(file, "utf8"));
    } catch {
      /* try the legacy path */
    }
  }
  return {};
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
