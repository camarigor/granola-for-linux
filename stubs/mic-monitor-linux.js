/**
 * Meeting auto-detection for Linux, over PipeWire.
 *
 * Granola notices a meeting has started by watching which applications are
 * holding the microphone. macOS gets that from a native module; Windows from
 * another one; on Linux the app short-circuits to "nobody is recording" and
 * gives up (see loader.js, which swaps that arm for this module).
 *
 * The whole contract is one function:
 *
 *     subscribe(callback) -> unsubscribe
 *     callback([{ bundleId, pid, deviceUID }, ...])
 *
 * `bundleId` is not a Linux concept, but the app keys off Apple bundle
 * identifiers on every platform, the Windows monitor maps chrome.exe to
 * com.google.Chrome rather than inventing its own names, so this maps Linux
 * executables onto the same identifiers.
 *
 * Requires pw-dump (pipewire-bin). Without it, auto-detection is simply off:
 * recording by hand keeps working.
 */
"use strict";

const { execFile } = require("child_process");
const fs = require("fs");

const POLL_MS = Number(process.env.GRANOLA_MIC_POLL_MS) || 1000;

// Linux executable name -> the Apple bundle id the app recognises. Mirrors the
// table in the bundle's own Windows monitor, translated to Linux binaries.
const BUNDLE_BY_BINARY = {
  chrome: "com.google.Chrome",
  "google-chrome": "com.google.Chrome",
  "google-chrome-stable": "com.google.Chrome",
  "google-chrome-beta": "com.google.Chrome.beta",
  chromium: "com.google.Chrome",
  "chromium-browser": "com.google.Chrome",
  firefox: "org.mozilla.firefox",
  "firefox-bin": "org.mozilla.firefox",
  "firefox-esr": "org.mozilla.firefox",
  brave: "com.brave.Browser",
  "brave-browser": "com.brave.Browser",
  vivaldi: "com.vivaldi.Vivaldi",
  "vivaldi-bin": "com.vivaldi.Vivaldi",
  opera: "com.operasoftware.Opera",
  msedge: "com.microsoft.edgemac",
  "microsoft-edge": "com.microsoft.edgemac",
  "microsoft-edge-stable": "com.microsoft.edgemac",
  zen: "app.zen-browser.zen",
  "zen-browser": "app.zen-browser.zen",
  zoom: "us.zoom.xos",
  ZoomLauncher: "us.zoom.xos",
  teams: "com.microsoft.teams2",
  "teams-for-linux": "com.microsoft.teams2",
  slack: "com.tinyspeck.slackmacgap",
  discord: "com.hnc.Discord",
  webex: "com.cisco.webexmeetingsapp",
  whatsapp: "net.whatsapp.WhatsApp",
  "whatsapp-for-linux": "net.whatsapp.WhatsApp",
  ferdium: "org.ferdium.ferdium",
};

let warnedMissingTool = false;

/** True when `pid` is this process or one of its descendants. */
function isOwnProcess(pid) {
  let current = Number(pid);
  for (let hops = 0; current > 1 && hops < 20; hops++) {
    if (current === process.pid) return true;
    try {
      // /proc/<pid>/stat: the comm field can contain spaces and parentheses,
      // so ppid is read after the LAST ')'.
      const stat = fs.readFileSync(`/proc/${current}/stat`, "utf8");
      const fields = stat.slice(stat.lastIndexOf(")") + 2).split(" ");
      current = Number(fields[1]); // ppid
    } catch {
      return false; // process gone: not ours to worry about
    }
  }
  return false;
}

function parseCapturingApps(dump) {
  const clients = new Map();
  for (const object of dump) {
    if (String(object.type || "").endsWith("Client")) clients.set(object.id, object);
  }

  const apps = new Map(); // bundleId -> entry, so one app counts once
  for (const object of dump) {
    const props = (object.info && object.info.props) || {};
    if (props["media.class"] !== "Stream/Input/Audio") continue;

    // The capturing node names the app but not its pid; that lives on the
    // client the node belongs to.
    const client = clients.get(props["client.id"]);
    const clientProps = (client && client.info && client.info.props) || {};
    const binary = clientProps["application.process.binary"]
      || props["application.process.binary"]
      || props["application.name"]
      || "";
    const pid = Number(clientProps["application.process.id"] || props["application.process.id"] || 0);

    const bundleId = BUNDLE_BY_BINARY[binary] || BUNDLE_BY_BINARY[binary.toLowerCase()];
    if (!bundleId) continue;          // not an app the meeting UI knows about
    if (pid && isOwnProcess(pid)) continue; // Granola recording is not a meeting

    if (!apps.has(bundleId)) {
      apps.set(bundleId, { bundleId, pid, deviceUID: "pipewire" });
    }
  }
  return [...apps.values()];
}

/**
 * pw-dump is not always strict JSON, in two ways seen in practice:
 *
 *  - Concatenated documents. When objects change while the dump is being
 *    written, an update array follows the first one: `[…][…]`. That happens
 *    exactly when a stream starts or stops, which is when this matters most.
 *  - A stray array where a property name belongs, e.g. `"ProcessLatency": […],
 *    [ ] }`. Emitted by a pw-dump older than the server it queries (seen with
 *    libpipewire 0.3.65 against a newer daemon).
 *
 * Both are repaired here rather than letting a whole poll be lost.
 */
function parseDump(text) {
  try {
    return JSON.parse(text);
  } catch {
    const repaired = text
      .replace(/,\s*\[\s*\]\s*(?=[}\]])/g, "") // bare array member
      .replace(/\]\s*\[/g, ",");               // concatenated documents
    return JSON.parse(repaired);
  }
}

function readCapturingApps(done) {
  execFile("pw-dump", [], { maxBuffer: 32 * 1024 * 1024, timeout: 5000 }, (err, stdout) => {
    if (err) {
      if (!warnedMissingTool) {
        warnedMissingTool = true;
        console.warn(
          `[granola-for-linux] meeting auto-detection off: pw-dump failed (${err.message}). ` +
          "Install pipewire-bin; recording by hand is unaffected."
        );
      }
      return done([]);
    }
    try {
      done(parseCapturingApps(parseDump(stdout)));
    } catch (parseErr) {
      console.warn("[granola-for-linux] could not read pw-dump output:", parseErr.message);
      done([]);
    }
  });
}

/**
 * Matches the shape the app's platform switch expects: it is handed the
 * callback and must return the unsubscribe function.
 */
function subscribe(callback) {
  let lastKey = null;
  let stopped = false;

  const tick = () => {
    readCapturingApps((apps) => {
      if (stopped) return;
      // Publish only on change: the app re-renders and re-evaluates its
      // recording prompt on every call.
      const key = apps.map((a) => a.bundleId).sort().join(",");
      if (key === lastKey) return;
      lastKey = key;
      try {
        callback(apps);
      } catch (err) {
        console.warn("[granola-for-linux] mic monitor callback threw:", err.message);
      }
    });
  };

  tick();
  const timer = setInterval(tick, POLL_MS);
  if (typeof timer.unref === "function") timer.unref();

  return () => {
    stopped = true;
    clearInterval(timer);
  };
}

module.exports = { subscribe, parseCapturingApps, parseDump, BUNDLE_BY_BINARY };
