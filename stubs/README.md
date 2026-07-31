# Stubs

JS replacements for Granola's macOS native modules. `loader.js` hooks Node's
`.node` loader and injects these, so the minified bundle is **never edited**
(which would break on every app release).

| Stub | Strategy |
|---|---|
| `granola.js` | **Instrumented.** Logs every call (method, argument types) and answers callbacks with silence so the app keeps moving. This is the tool that reveals the audio-capture contract for Phase 2. |
| `keychain.js` | Real, simplified implementation: a 600-mode file under `~/.config/granola-for-linux`. Swap for libsecret later. |
| `sqlite-updatehook-shim.js` | Adds `updateHook`/`commitHook`/`rollbackHook` to the public better-sqlite3 build, Granola ships a fork that has them. Applied to *our* build, not the app's. |
| the rest | No-op proxies: any method returns `undefined` and logs the call. These are OS integrations (Dock, haptics, OCR, meeting automation) that do not affect recording. |

Modules without a stub appear in the log as `MISSING STUB: <name>`, the loader
returns an object that throws a descriptive error instead of killing the app, so
a single run reveals everything that is still missing.

Environment: `GRANOLA_STUB_VERBOSE=0` silences logs; `GRANOLA_APP_DIR` points at
a different extracted app; `GRANOLA_TRACE_PROTOCOL`, `GRANOLA_TRACE_NET` and
`GRANOLA_TRACE_ERRORS` toggle the tracing hooks.
