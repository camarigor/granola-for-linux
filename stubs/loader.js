/**
 * Runtime shim loader for running the Granola macOS build on Linux.
 *
 * The bundle requires `.../native/<name>.node` files that are Mach-O binaries
 * and cannot load here. Instead of patching the minified bundle, which would
 * break on every Granola release, we replace Node's `.node` loader: requires
 * for Granola's native modules resolve to the JS stubs in stubs/modules/, while
 * genuine third-party natives keep their normal path (or a Linux rebuild).
 *
 * It also fixes up runtime state the app assumes about a macOS .app bundle
 * (resourcesPath, getAppPath, the app:// protocol handler) and installs tracing
 * that surfaces errors the app would otherwise swallow.
 *
 * Usage: electron stubs/loader.js   (it requires the real main at the end)
 */
const path = require("path");
const fs = require("fs");
const Module = require("module");

const APP_DIR = process.env.GRANOLA_APP_DIR || path.join(__dirname, "..", "work", "app-src");
const STUB_DIR = path.join(__dirname, "modules");
const LINUX_NATIVE_DIR = process.env.GRANOLA_LINUX_NATIVE || "/opt/native-linux";
const VERBOSE = process.env.GRANOLA_STUB_VERBOSE !== "0";

const log = (...a) => VERBOSE && console.log("[stub]", ...a);

// Available stubs: .node basename -> path of our JS replacement
const stubs = new Map();
for (const f of fs.existsSync(STUB_DIR) ? fs.readdirSync(STUB_DIR) : []) {
  if (f.endsWith(".js")) stubs.set(path.basename(f, ".js"), path.join(STUB_DIR, f));
}
log(`${stubs.size} stubs loaded from ${STUB_DIR}`);

const originalNodeLoader = Module._extensions[".node"];

Module._extensions[".node"] = function (module, filename) {
  const name = path.basename(filename, ".node");
  if (stubs.has(name)) {
    log(`intercepted: ${name}`);
    module.exports = require(stubs.get(name));
    return;
  }
  // Third-party natives rebuilt for Linux (the bundle ships macOS builds).
  // e.g. better_sqlite3, without this the require fails with
  // "invalid ELF header" and the UI never mounts.
  const linuxBuild = path.join(LINUX_NATIVE_DIR, `${name}.node`);
  if (fs.existsSync(linuxBuild)) {
    log(`using Linux build: ${name}`);
    return originalNodeLoader(module, linuxBuild);
  }
  try {
    return originalNodeLoader(module, filename);
  } catch (err) {
    // Unknown incompatible native: don't kill the app, return a proxy that
    // throws a descriptive error on use, so one run reveals everything missing.
    console.warn(`[stub] MISSING STUB: ${name} (${err.code || err.message})`);
    module.exports = new Proxy({}, {
      get: (_t, prop) => (typeof prop === "string" && prop !== "then"
        ? () => { throw new Error(`granola-for-linux: ${name}.${String(prop)}() not implemented`); }
        : undefined),
    });
  }
};

// The app resolves its assets (dist-app/index.html, app:// protocol) from
// process.resourcesPath, which on macOS is Granola.app/Contents/Resources.
// Launched as `electron loader.js`, Electron points it at its own directory
// (/opt/electron/resources), which is empty: the renderer then fails with
// net::ERR_FAILED and the window stays blank. Redirect it to the extracted app.
try {
  Object.defineProperty(process, "resourcesPath", {
    value: APP_DIR,
    writable: false,
    configurable: true,
  });
  log(`resourcesPath -> ${process.resourcesPath}`);
} catch (err) {
  console.warn("[stub] could not set resourcesPath:", err.message);
}

// Same story for app.getAppPath(): it returns the loader's directory, and the
// app:// handler resolves assets relative to it.
try {
  const { app: electronApp } = require("electron");
  if (electronApp && typeof electronApp.getAppPath === "function") {
    electronApp.getAppPath = () => APP_DIR;
    log(`getAppPath -> ${APP_DIR}`);
  }
} catch (err) {
  log("could not set getAppPath:", err.message);
}

// app:// resolution straight from disk.
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
  // the host ('ui') is a logical namespace; files live under dist-app/
  const rel = decodeURIComponent(url.pathname).replace(/^\/+/, "");
  const candidates = [
    path.join(APP_DIR, "dist-app", rel),
    path.join(APP_DIR, "dist-app", url.host || "", rel),
    path.join(APP_DIR, rel),
  ];
  for (const file of candidates) {
    if (!file.startsWith(APP_DIR)) continue; // guard against path traversal
    try {
      const body = fs.readFileSync(file);
      if (servedCount++ === 0) log(`serving assets from disk (${why})`);
      return new Response(body, {
        status: 200,
        headers: { "content-type": MIME[path.extname(file).toLowerCase()] || "application/octet-stream" },
      });
    } catch {
      /* try next candidate */
    }
  }
  if (why !== "local shortcut") console.warn(`[stub:proto] not found: ${request.url}`);
  return new Response("not found", { status: 404 });
}

// Wrap the custom protocol registration. The app's own handler uses
// net.fetch('file://…'), which Chromium refuses here even though the files are
// present and readable, and letting it try first produced hundreds of failed
// requests until loading died with net::ERR_INSUFFICIENT_RESOURCES.
if (process.env.GRANOLA_TRACE_PROTOCOL !== "0") {
  try {
    const { protocol } = require("electron");
    if (protocol && typeof protocol.handle === "function") {
      const originalHandle = protocol.handle.bind(protocol);
      protocol.handle = (scheme, handler) => {
        log(`protocol.handle registered: ${scheme}://`);
        return originalHandle(scheme, async (request) => {
          const local = serveFromDisk(request, "local shortcut");
          if (local.status === 200) return local;
          try {
            return await handler(request);
          } catch (err) {
            console.warn(`[stub:proto] ${request.url} -> ${err.message}`);
            return new Response("not found", { status: 404 });
          }
        });
      };
    }
  } catch (err) {
    log("could not instrument protocol:", err.message);
  }
}

// Log network failures with URL and reason. The app only reports
// "network-error [object Object]" to its console, which says nothing.
if (process.env.GRANOLA_TRACE_NET !== "0") {
  try {
    const { app: electronApp, session } = require("electron");
    electronApp.whenReady().then(() => {
      const seen = new Set();
      session.defaultSession.webRequest.onErrorOccurred((details) => {
        const key = `${details.error}:${(details.url || "").split("?")[0]}`;
        if (seen.has(key) || seen.size > 40) return;
        seen.add(key);
        console.warn(`[stub:net] ${details.error} <- ${details.url}`);
      });
    });
  } catch (err) {
    log("could not instrument webRequest:", err.message);
  }
}

// The app catches renderer exceptions in a React error boundary and ships them
// to Sentry, showing only "Something went wrong", the real error never reaches
// the log. Inject listeners per window to surface message, file and stack.
if (process.env.GRANOLA_TRACE_ERRORS !== "0") {
  try {
    const { app: electronApp, BrowserWindow } = require("electron");
    electronApp.whenReady().then(() => {
      const attach = (win) => {
        const wc = win.webContents;
        wc.on("did-finish-load", () => {
          wc.executeJavaScript(`
            (() => {
              if (window.__granolaLinuxTrace) return;
              window.__granolaLinuxTrace = true;
              window.addEventListener('error', (e) => {
                console.log('[APP-ERROR]', e.message, '@', e.filename + ':' + e.lineno,
                            (e.error && e.error.stack || '').split('\\n').slice(0,3).join(' | '));
              });
              window.addEventListener('unhandledrejection', (e) => {
                const r = e.reason;
                console.log('[APP-REJECT]', (r && (r.stack || r.message)) || String(r));
              });
            })();
          `).catch(() => {});
        });
      };
      BrowserWindow.getAllWindows().forEach(attach);
      electronApp.on("browser-window-created", (_e, win) => attach(win));
    });
  } catch (err) {
    log("could not instrument renderer errors:", err.message);
  }
}

// shell.openExternal dies silently in the container: there is no browser and
// no xdg-open (the log shows a bare "xdg-open" line and the login flow stops
// at /login-in-progress). Drop the URL into the bridge directory instead, 
// run.sh watches it on the host and opens the user's real browser, where
// their Google session lives.
const BRIDGE_DIR = process.env.GRANOLA_BRIDGE_DIR;
if (BRIDGE_DIR) {
  try {
    const { shell } = require("electron");
    const originalOpenExternal = shell.openExternal.bind(shell);
    let openSeq = 0;
    shell.openExternal = async (url) => {
      let target = String(url);
      // api.granola.ai/v1/auth 500s on any platform value other than
      // macos/windows (bisected 2026-07-31: linux/darwin/mac -> 500). The app
      // sends process.platform verbatim when its map has no entry. We run the
      // genuine macOS bundle, so present it as such.
      try {
        const u = new URL(target);
        if (u.hostname.endsWith("granola.ai") && u.searchParams.get("platform") === "linux") {
          u.searchParams.set("platform", "macos");
          target = u.toString();
          console.log("[stub:open-external] rewrote platform=linux -> macos (backend 500s on unknown values)");
        }
      } catch { /* not a parseable URL, pass through as-is */ }
      console.log(`[stub:open-external] ${target}`);
      try {
        // two-step write so the host watcher never reads a half-written file
        const base = path.join(BRIDGE_DIR, `open-${process.pid}-${openSeq++}`);
        fs.writeFileSync(`${base}.tmp`, target);
        fs.renameSync(`${base}.tmp`, `${base}.url`);
      } catch (err) {
        console.warn("[stub:open-external] bridge write failed:", err.message);
        return originalOpenExternal(target);
      }
    };
    log(`openExternal -> bridge at ${BRIDGE_DIR}`);
  } catch (err) {
    log("could not instrument shell.openExternal:", err.message);
  }
}

// Surface how the OAuth callback is expected to arrive. On macOS the deep
// link comes in via the 'open-url' event; on Linux a second instance gets
// the granola:// URL in argv. Log both so the callback mechanism is visible.
try {
  const { app: electronApp } = require("electron");
  electronApp.on("open-url", (_e, url) => {
    console.log(`[stub:deep-link] open-url: ${url}`);
  });
  electronApp.on("second-instance", (_e, argv) => {
    console.log(`[stub:deep-link] second-instance argv: ${JSON.stringify(argv)}`);
  });
} catch (err) {
  log("could not instrument deep links:", err.message);
}

// Deep-link return path: the host browser has no granola:// handler, so the
// OAuth callback cannot reach the container on its own. Any callback-*.url
// file dropped in the bridge (see scripts/deliver-callback.sh) is re-emitted
// as an 'open-url' event, the channel the app's OpenURLHandler listens on, 
// with a second-instance argv fallback.
if (BRIDGE_DIR) {
  try {
    const { app: electronApp } = require("electron");
    const deliver = (url) => {
      console.log(`[stub:deep-link] delivering from bridge: ${url.slice(0, 120)}`);
      electronApp.emit("open-url", { preventDefault() {} }, url);
    };
    setInterval(() => {
      let files;
      try { files = fs.readdirSync(BRIDGE_DIR); } catch { return; }
      for (const f of files) {
        if (!f.startsWith("callback-") || !f.endsWith(".url")) continue;
        const p = path.join(BRIDGE_DIR, f);
        try {
          const url = fs.readFileSync(p, "utf8").trim();
          fs.unlinkSync(p);
          if (url) deliver(url);
        } catch (err) {
          console.warn("[stub:deep-link] bridge read failed:", err.message);
        }
      }
    }, 500).unref();
    log("deep-link bridge watcher armed");
  } catch (err) {
    log("could not arm deep-link watcher:", err.message);
  }
}

// The app's structured logger prints "sqlite-exec-error [object Object]" to
// the terminal, the detail object (the actual SQL error) never survives
// Chromium's console serialisation, and the window error listeners above never
// fire because the app catches the exception itself. Attach the DevTools
// protocol instead: Runtime.consoleAPICalled hands us the real argument
// objects, which we expand to JSON. Runtime.enable also replays messages
// logged before we attached, so early boot errors are not lost.
if (process.env.GRANOLA_TRACE_CONSOLE !== "0") {
  try {
    const { app: electronApp, BrowserWindow } = require("electron");
    const INTERESTING = /error|fail|warn|went wrong/i;

    const shallowPreview = (p) => p && p.properties
      ? "{" + p.properties.map((x) => `${x.name}: ${x.value}`).join(", ") + "}"
      : null;

    const expandArg = async (wc, a) => {
      if (!a.objectId) return String(a.value ?? a.description ?? a.type);
      try {
        const r = await wc.debugger.sendCommand("Runtime.callFunctionOn", {
          objectId: a.objectId,
          returnByValue: true,
          functionDeclaration: `function () {
            const seen = new Set();
            try {
              return JSON.stringify(this, (k, v) => {
                if (v instanceof Error) return { message: v.message, stack: v.stack };
                if (typeof v === "object" && v !== null) {
                  if (seen.has(v)) return "[circular]";
                  seen.add(v);
                }
                return v;
              }).slice(0, 6000);
            } catch (e) { return "unserializable: " + e.message; }
          }`,
        });
        return (r.result && r.result.value) || shallowPreview(a.preview) || a.description || "?";
      } catch {
        // objectId may be gone for replayed pre-attach messages; the shallow
        // preview (first ~5 properties) is still better than [object Object].
        return shallowPreview(a.preview) || a.description || "?";
      }
    };

    electronApp.whenReady().then(() => {
      const attach = (win) => {
        const wc = win.webContents;
        try {
          wc.debugger.attach("1.3");
        } catch {
          return; // already attached
        }
        wc.debugger.on("message", async (_e, method, params) => {
          if (method !== "Runtime.consoleAPICalled") return;
          const args = params.args || [];
          const first = String(args[0] && (args[0].value ?? args[0].description) || "");
          if (!INTERESTING.test(first) && params.type !== "error") return;
          const parts = await Promise.all(args.map((a) => expandArg(wc, a)));
          console.log(`[APP-LOG:${params.type}]`, parts.join(" "));
        });
        wc.debugger.sendCommand("Runtime.enable").catch(() => {});
      };
      BrowserWindow.getAllWindows().forEach(attach);
      electronApp.on("browser-window-created", (_e, win) => attach(win));
    });
  } catch (err) {
    log("could not attach console tracer:", err.message);
  }
}

// Hand over to the real app
const mainPath = path.join(APP_DIR, "dist-electron", "main", "index.js");
if (!fs.existsSync(mainPath)) {
  console.error(`[stub] ERROR: main not found at ${mainPath}`);
  console.error("[stub] run ./scripts/extract.sh first");
  process.exit(1);
}
log(`loading main: ${mainPath}`);
require(mainPath);
