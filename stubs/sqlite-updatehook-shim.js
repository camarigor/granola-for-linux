/**
 * `updateHook` shim for better-sqlite3-multiple-ciphers.
 *
 * Granola ships a FORK of better-sqlite3-multiple-ciphers 12.9.0 exposing
 * `db.updateHook(cb)` - an API absent from every public version (checked
 * 12.8.0, 12.9.0, 12.10.0 and 12.11.1: zero hits). Since their binary is
 * Mach-O and the fork's source is not public, on Linux we use the public package
 * and must supply the method, otherwise startup dies with
 * "updateHook is not a function" and the app never leaves the splash screen.
 *
 * The original hook lets the app know when rows changed (sqlite3_update_hook)
 * so it can react in the UI. This shim stores the callback but never fires it:
 * the UI may not refresh itself after writes, but the app boots. If Phase 2 needs
 * reactivity, it can be emulated by firing the callback after each `run()`.
 */
"use strict";

module.exports = function applyUpdateHookShim(Database) {
  if (!Database || !Database.prototype) return Database;
  if (typeof Database.prototype.updateHook === "function") return Database;

  Database.prototype.updateHook = function updateHook(callback) {
    if (typeof callback === "function") {
      // kept for inspection/future use; never invoked for now
      this.__updateHookCallback = callback;
    } else {
      delete this.__updateHookCallback;
    }
    return this;
  };

  // Some forks also expose these; no-ops keep the surface compatible.
  for (const name of ["commitHook", "rollbackHook"]) {
    if (typeof Database.prototype[name] !== "function") {
      Database.prototype[name] = function () { return this; };
    }
  }

  return Database;
};
