'use strict';
module.exports = require('./database');
module.exports.SqliteError = require('./sqlite-error');

// --- granola-for-linux: ver stubs/sqlite-updatehook-shim.js ---
try {
  require('/app/stubs/sqlite-updatehook-shim.js')(module.exports);
} catch (err) {
  console.warn('[granola-for-linux] shim de updateHook não aplicado:', err.message);
}
