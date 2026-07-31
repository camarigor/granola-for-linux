/**
 * `updateHook` for better-sqlite3-multiple-ciphers.
 *
 * Granola ships a FORK of the package exposing `db.updateHook(cb)`, absent from
 * every public version (checked 12.8.0, 12.9.0, 12.10.0 and 12.11.1). Their
 * binary is Mach-O and the fork is not public, so on Linux we build the public
 * package and supply the method ourselves.
 *
 * This is NOT cosmetic. It is the app's change-notification backbone
 * (dist-electron/sqlite_worker/worker.js):
 *
 *     db.updateHook((op, database, table) => { changed.add(table); schedule() })
 *     // → parentPort.postMessage({ type: 'change', tables: [...] })
 *
 * sqlite_process fans that message out to every subscriber, which invalidates
 * the query cache so the UI re-reads and re-renders. A no-op leaves the app
 * running on stale cached reads: panels appear locally but are never pushed to
 * the server, so "generate notes" ends in
 * `update-document-panel 404 Document panel not found`.
 *
 * The public package cannot reach sqlite3_update_hook, so we emulate it: every
 * write statement reports the tables it touched, resolved through SQLite's
 * `tables_used()` (available because the Dockerfile compiles with
 * SQLITE_ENABLE_BYTECODE_VTAB).
 *
 * Differences from the real hook, all benign for this consumer, it only
 * collects table names into a Set:
 *   - fires once per statement, not once per row;
 *   - fires even if the surrounding transaction later rolls back (an extra
 *     cache invalidation costs a re-query, never correctness);
 *   - `rowid` is only meaningful for INSERTs.
 */
"use strict";

const HOOK = Symbol("granolaUpdateHook");
const STMT = Symbol("granolaTablesUsedStmt");
const CACHE = Symbol("granolaTablesUsedCache");

// Cheap pre-filter: only these statements can change rows.
const IS_WRITE = /\b(?:insert|update|delete|replace)\b/i;

// Fallback when tables_used() is unavailable (e.g. a build without the flag).
const WRITE_TARGET =
  /(?:insert\s+(?:or\s+\w+\s+)?into|update\s+(?:or\s+\w+\s+)?|delete\s+from|replace\s+into)\s+["'`[]?([A-Za-z_][\w$]*)["'`\]]?/gi;

const CACHE_LIMIT = 500;

function tablesFromRegex(sql) {
  const out = new Set();
  WRITE_TARGET.lastIndex = 0;
  let m;
  while ((m = WRITE_TARGET.exec(sql))) out.add(m[1]);
  return [...out];
}

// `stmt` is the tables_used() lookup, prepared with the ORIGINAL prepare so
// resolving a statement never re-enters the hook. It is null when the build
// lacks SQLITE_ENABLE_BYTECODE_VTAB, in which case we parse the SQL instead.
function writtenTables(db, stmt, sql) {
  let cache = db[CACHE];
  if (!cache) cache = db[CACHE] = new Map();
  const hit = cache.get(sql);
  if (hit) return hit;

  let tables;
  try {
    tables = stmt ? stmt.all(sql).map((r) => r.name) : tablesFromRegex(sql);
  } catch {
    // tables_used() rejects some inputs (multi-statement scripts, DDL);
    // the regex still catches the common INSERT/UPDATE/DELETE shapes.
    tables = tablesFromRegex(sql);
  }

  if (cache.size >= CACHE_LIMIT) cache.clear();
  cache.set(sql, tables);
  return tables;
}

module.exports = function applyUpdateHookShim(Database) {
  if (!Database || !Database.prototype) return Database;
  const proto = Database.prototype;
  // A genuine fork (or a second application of this shim) wins.
  if (typeof proto.updateHook === "function") return Database;

  const originalPrepare = proto.prepare;
  const originalExec = proto.exec;

  const lookupStatement = (db) => {
    if (db[STMT] !== undefined) return db[STMT];
    try {
      db[STMT] = originalPrepare.call(
        db,
        "SELECT DISTINCT name FROM tables_used(?) WHERE wr = 1 AND type = 'table'"
      );
    } catch {
      db[STMT] = null; // no BYTECODE_VTAB, writtenTables() falls back to regex
    }
    return db[STMT];
  };

  const fire = (db, sql, info) => {
    const callback = db[HOOK];
    if (!callback) return;
    let tables;
    try {
      tables = writtenTables(db, lookupStatement(db), sql);
    } catch {
      return;
    }
    const rowid = (info && info.lastInsertRowid) || 0;
    const op = /^\s*insert/i.test(sql) ? "insert" : /^\s*delete/i.test(sql) ? "delete" : "update";
    for (const table of tables) {
      try {
        callback(op, "main", table, rowid);
      } catch (err) {
        console.warn("[granola-for-linux] updateHook callback threw:", err.message);
      }
    }
  };

  proto.updateHook = function updateHook(callback) {
    if (typeof callback === "function") this[HOOK] = callback;
    else delete this[HOOK];
    return this;
  };

  // Not part of the observed contract, but forks that expose updateHook
  // usually expose these too; keep the surface consistent.
  for (const name of ["commitHook", "rollbackHook"]) {
    if (typeof proto[name] !== "function") {
      proto[name] = function () { return this; };
    }
  }

  proto.prepare = function prepare(sql, ...rest) {
    const stmt = originalPrepare.call(this, sql, ...rest);
    if (!stmt || typeof sql !== "string" || !IS_WRITE.test(sql)) return stmt;

    const db = this;
    // Writes land through run(); with a RETURNING clause they come back
    // through get()/all() instead, so all three are wrapped.
    for (const method of ["run", "get", "all"]) {
      const original = stmt[method];
      if (typeof original !== "function") continue;
      stmt[method] = function (...args) {
        const result = original.apply(this, args);
        fire(db, sql, result);
        return result;
      };
    }
    return stmt;
  };

  proto.exec = function exec(sql, ...rest) {
    const result = originalExec.call(this, sql, ...rest);
    if (typeof sql === "string" && IS_WRITE.test(sql)) fire(this, sql, null);
    return result;
  };

  return Database;
};
