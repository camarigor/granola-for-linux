# Reverse-engineering findings

Survey of `Granola - AI Notepad.dmg`, app **v7.452.1** (built 2026-07-30),
analysed on 2026-07-31. Observations only, no app code is reproduced here.

## The app is Electron

- `Contents/Resources/app.asar`, 58.7 MB (93 MB unpacked)
- `package.json`: `@granola/electron`, main = `dist-electron/main/index.js`
- Declared internal repo: `github.com/granola-inc/granola-electron` (private)
- `Contents/MacOS/Granola` is only 119 KB: it is the launcher; the weight sits in
  the Electron Framework (`libEGL`, `libGLESv2`, `libvk_swiftshader`, `libffmpeg`)
- Auto-update via **Squirrel.Mac** (plus `Mantle`, `ReactiveObjC`)
- **Electron 42.7.0**, read from `CFBundleVersion` in
  `Electron Framework.framework/Versions/A/Resources/Info.plist`
  (`CFBundleShortVersionString` is empty)

## The architecture is already cross-platform

Counts in `dist-electron/main/index.js`:

| Signal | Occurrences |
|---|---|
| `process.platform` | 229 |
| `darwin` | 142 |
| **`win32`** | **124** |
| `linux` | 19 |

Native module paths referenced: `native/client`, `native/diarizer`,
**`native/windows`**.

**Reading:** a Windows layer exists and is nearly as extensive as the macOS one.
Porting to Linux means writing the *third* native implementation, not rewriting
the product. The 19 `linux` hits are likely defensive checks, to be confirmed.

## Native modules (all Mach-O, closed source)

`Contents/Resources/native/`, 15 files:

| Module | Apple frameworks | Needed to record? |
|---|---|---|
| **granola** | **ScreenCaptureKit, CoreAudio, AVFoundation** | **YES, this is the capture** |
| diarizer (`native/diarizer`) |, | likely (speaker separation) |
| keychain |, | yes (persisting login) |
| eventkit | EventKit | no (calendar) |
| screen_capture_ocr | ScreenCaptureKit | no |
| third_party_meeting_automation | AppKit | no (drives Zoom/Meet) |
| mac_webcam_sysext | AVFoundation | no |
| macos_mic_apps_with_devices | CoreAudio | no (lists apps using the mic) |
| docktile, haptics, mission_control, paste, procmem, sleep, tcc | AppKit and friends | no (OS integrations) |

Third-party natives in `app.asar.unpacked/node_modules`:
`better-sqlite3-multiple-ciphers`, `@napi-rs/*`, `keyspy`,
`electron-click-drag-plugin`, `registry-js` (Windows), `win-ca` (Windows).

> `registry-js` and `win-ca` shipping inside the **macOS** package reinforces
> that one bundle serves both platforms.

## Main-process helpers

`dist-electron/` splits work into per-purpose processes, several named after
macOS dependencies:

```
audio_process              mic_monitor_process        mic_monitor_v2_process
eventkit_process           macos_mic_apps_with_devices_process
mission_control_process    speaker_embedding_process  sqlite_process
main                       preload
```

`speaker_embedding_process` suggests part of the diarisation runs locally.

## Phase 1, obstacles hit and solved (2026-07-31)

Running `electron loader.js` against the extracted app, in the order they appeared:

| # | Symptom | Cause | Fix |
|---|---|---|---|
| 1 | `USER granola` does not exist | uid 1000 already belongs to `node` in the base image | use numeric `USER ${UID}` |
| 2 | `Electron failed to install correctly` | npm postinstall never fetched the binary; at runtime there is no write permission | download the official release zip at build time |
| 3 | **Black window**, `Exiting GPU process` | `libGL.so.1` missing in the container | install `libgl1 libglx-mesa0 libegl1 libgles2 libglapi-mesa libgl1-mesa-dri` |
| 4 | `net::ERR_FAILED` on every `app://ui/...` | the app's handler uses `net.fetch('file://…')`, which Chromium refuses here even with the file present and readable | the loader wraps `protocol.handle` and serves from disk |
| 5 | `net::ERR_INSUFFICIENT_RESOURCES` | letting the original handler try first meant 322 failed fetches | serve from disk **before** delegating |
| 6 | `better_sqlite3.node: invalid ELF header` | Mach-O binary; and the loader's require hook **does not reach the renderer**, which loads the `.node` itself | build the package against Electron headers and shadow it via bind-mount |
| 7 | `this[cppdb].updateHook is not a function` | Granola ships a **fork** of better-sqlite3-multiple-ciphers exposing `updateHook`; no public version has it (checked 12.8.0 / 12.9.0 / 12.10.0 / 12.11.1, zero hits) | `stubs/sqlite-updatehook-shim.js` adds a no-op method to our build |
| 8 | `sqlite-exec-error: no such table: tables_used` → React error boundary ("Something went wrong") | `tables_used()` is a SQLite **table-valued function** that only exists when compiled with `SQLITE_ENABLE_BYTECODE_VTAB` (sqlite.org/bytecodevtab.html). Granola's fork enables it; the public package does not. Their cacheStore feeds it every query to learn which tables are read/written (`wr` column) and pairs it with `updateHook` for reactive cache invalidation, the two fork features serve one system | the Dockerfile patches `deps/defines.gypi` before compiling (A/B-tested: same build fails without the flag, works with it) |
| 9 | notes never generate; `update-document-panel` → **404 Document panel not found** | **the no-op `updateHook` from #7.** It is not cosmetic: `sqlite_worker/worker.js` uses it as the change-notification backbone (`updateHook(cb)` → `postMessage({type:'change', tables})` → `sqlite_process` fans out → query cache invalidated → UI re-reads). Mute, the app never learns local rows changed, so the panel is created locally but never registered server-side and the follow-up update 404s | `stubs/sqlite-updatehook-shim.js` now **implements** the hook: write statements report their tables via `tables_used()` (the #8 fix), matching the real `(op, database, table, rowid)` signature |
| 10 | login and local notes lost on every restart | Electron's userData lived at `/home/electron-cache/.config/Electron` **inside** the container, with no volume | `run.sh` mounts `work/app-data` there |

Details worth keeping:

- **Compiling the sqlite package**: `npm install --runtime=electron --target=...`
  does **not** work (npm does not forward the flags to node-gyp); the
  `npm_config_runtime` / `npm_config_target` / `npm_config_disturl` environment
  variables do. Also, the bundle's version (12.9.0) **fails to compile** against
  Electron 42's V8 (`SetNativeDataProperty ambiguous`, `External::Value()`);
  12.11.1 compiles.
- **`process.resourcesPath` and `app.getAppPath()`** both point at the Electron
  directory when launching `electron <script>`; both must be redirected.
- **A screenshot of a window under i3 is not evidence**: a window on a hidden
  workspace captures as pure black even when healthy. Validate through the log
  (`ERR_FAILED`, `Uncaught`) instead of the image.
- **The window `error`/`unhandledrejection` listeners never fire**: the app
  catches its own exceptions and routes them to a structured logger, which the
  terminal flattens to `[object Object]`. The CDP tracer in `loader.js`
  (`GRANOLA_TRACE_CONSOLE`) attaches `webContents.debugger`, listens for
  `Runtime.consoleAPICalled` and expands object arguments via
  `Runtime.callFunctionOn` + `JSON.stringify`. Bonus: `Runtime.enable` replays
  messages logged before the attach, so early boot errors are not lost.
- **Testing an Electron-ABI native module without a display**:
  `ELECTRON_RUN_AS_NODE=1 /opt/electron/electron script.js` runs Electron as
  plain Node with the right ABI, no Chromium, no X11. This is how the
  `tables_used()` fix was A/B-verified inside a throwaway container.

### State at the end of Phase 1

**Phase 1 complete.** With all of the above applied, the app boots to its real
UI, the **login screen**, with no error boundary. The log shows the full
chain succeeding:

```
app-started {"wasFirstLaunch":true}      primary-window-created
sqlite-init-success                      sqlite-migrate-success
renderer-startup-complete                navigate {"pathname":"/login"}
transcription-set-desired-...            micApps is now []
```

The transcription subsystem initialises, microphone-app detection runs, and
integrations correctly report "no access token" for an unauthenticated session.
Closing the window does **not** exit the process (macOS menu-bar behaviour).

The only remaining startup error is non-blocking: `meet-consent-enable-failed`
, the app looks for `/app/native/x64/meet-consent-host`, a macOS helper binary
for the Google Meet consent flow (Phase 2 material).

**No native stub has been called yet**, the UI mounts without touching the
macOS modules. They should only come into play at login and, above all, when
recording (Phase 2).

## Phase 1.5, login (OAuth)

The login button calls `shell.openExternal(authUrl)`. In the container there is
no browser, so the loader writes the URL to a bridge directory and a watcher on
the host opens it in the user's real browser (`GRANOLA_BRIDGE_DIR` /
`scripts/run.sh`). Two obstacles found:

| # | Symptom | Cause | Fix |
|---|---|---|---|
| 9 | login click does nothing | `shell.openExternal` runs `xdg-open`, absent in the container; the flow stalls at `/login-in-progress` | loader intercepts `openExternal`, writes URL to bridge; host watcher opens it |
| 10 | auth page returns `{"message":"Internal Server Error"}` (HTTP 500) | `api.granola.ai/v1/auth` only accepts `platform=macos` or `platform=windows`. The app sends `process.platform` verbatim (`linux`) because its platform map has no Linux entry. **The backend 500s on any other value, even `darwin`** (bisected with curl 2026-07-31) | loader rewrites `platform=linux → macos` on `*.granola.ai` auth URLs. We run the genuine macOS bundle, so this is accurate |

The corrected URL 302-redirects into the WorkOS flow requesting Google scopes:
`userinfo.email`, `userinfo.profile`, `calendar.events`, `calendar.readonly`,
with `redirect_uri=https://api.granola.ai/v1/login-complete`.

### The deep-link return path

The callback comes back as a `granola://` link the host browser cannot route
into the container. The loader watches the bridge for `callback-*.url` files
and re-emits them as the `open-url` event the app already listens on;
`scripts/deliver-callback.sh` queues one (and converts the
`granola.ai/app-redirect?...` URL from the address bar into the deep link).

Read out of `dist-electron/main/index.js`:

- Accepted schemes: **`granola:` and `granola-dev:`**, `dTt = app.isPackaged ? "granola" : "granola-dev"` only affects *registration*; the parser (`G7`) takes both, so running unpackaged is not a problem.
- The action is the **hostname**, not the path: `granola://login-complete?code=…`.
- Allowed actions: `login-complete`, `join-list`, `new-document`, `put-document`, `try-recipe`, `ws-migration-banner`, `open-workspace`, `open-document`, `open-settings`, `set-feature-flags`, `turbopuffer-search`, `zoom-redirect`, `start-demo`, `open`. Anything else logs `url-path-not-allowed`.
- Query values `"true"`/`"false"` are coerced to booleans before schema validation.
- `https://notes.granola.ai/...` links are handled by a separate parser (`ISt`).

### Three ways the login fails (all diagnosed, none our bug)

| Symptom | Cause | Rule |
|---|---|---|
| WorkOS **"Invalid state"** after logging in | the `state` is a JWT whose `exp - iat` is exactly **900 s**; a tab left sitting expires | complete the flow within 15 min of the tab opening |
| Google **"Something went wrong"** | **two concurrent authorization requests** for the same sign-in (the app opened one, a second was opened by hand), AuthKit tracks the latest session on `auth.granola.ai` and the older one dies | exactly one tab per sign-in; let the app open it |
| `login-complete-ignored-not-on-login-in-progress` | the renderer must be sitting on the `/login-in-progress` route when the callback lands | never restart or close the app between clicking and delivering |

**Result: login works.** `auth-electron-set-tokens {"signInMethod":"CrossAppAuth"}`
→ `navigate /` → `Preferences synced` → `Document lists metadata sync complete`
→ `full-sync-complete`. **The backend accepts a non-official client**, no
attestation, no platform check beyond the `/v1/auth` parameter above.

## Phase 2, recording (mostly already working)

The assumption was that recording required porting `granola.node`. It does not.
The log says:

```
received-start-audio-capture {"sampleRate":16000,"capture_method":"browser"}
```

**There is a browser capture path**, Chromium's own APIs, no native module, 
and it serves *both* sources. Two transcription handlers connect
(`source: microphone`, `source: system`), both reach
`transcription-first-buffer-sent-timestamp`, and both report latency from the
providers (`assembly-universal`, `deepgram`). Recording, transcription and
automatic note generation all work today on Linux.

That matters for meeting apps: capture happens at the OS audio layer, so
**Teams web, teams-for-linux, Zoom and Meet are all the same** to Granola. It
records your microphone and the system output, never "from an app".

The native module's remaining value:

| Feature | Browser path | Needs `granola.node`? |
|---|---|---|
| Record mic + system audio | works | no |
| Live transcription | works | no |
| Automatic note generation | works | no |
| Input device enumeration/selection | untested | probably |
| Echo cancellation tuning (`disableEchoCancellationOnHeadphones`) | n/a | probably |
| **Meeting auto-detection** (`micApps`: which apps hold the mic) | absent | yes, needs a PipeWire equivalent |

The contract, read from `dist-electron/audio_process/index.js`, if it is ever
implemented:

```js
$.startAudioCapture(useCoreAudio, disableEchoCancellationOnHeadphones,
                    enableAutomaticGainCompensation, sampleRate,
                    (microphoneBuffer, systemAudioBuffer, timestamps) => …)
```

Plus `stopAudioCapture`, `getInputDevices`, `setInputDevice`,
`getAudioCaptureStatus`, `requestMicrophonePermission` and four callback
setters. Buffers are mono 16-bit PCM; the app writes them as
`<date>_microphone.wav` and `<date>_system.wav`.

Two gifts in that file: the native library path arrives as **`process.argv[2]`**
(so our own `.node` can be pointed at without patching the bundle), and the TCC
permission gate is skipped off-macOS, `qKe()` returns
`{audioCapture:'authorized', screenCapture:'authorized'}` when
`process.platform !== 'darwin'`.

## Phase 3, packaging

Everything that works in the dev container has to survive being installed, and
two defects only existed on that side.

| # | Symptom | Cause | Fix |
|---|---|---|---|
| 11 | login could never start from a .deb install | the `platform=linux → macos` rewrite sat inside the container-only bridge block, so an installed app would send the value that makes `api.granola.ai/v1/auth` answer 500 | the rewrite applies to every install; only the bridge detour stays conditional |
| 12 | **second** launch hangs before the window opens (`Failed to start service worker`, then a storage IO error) | the app installs React and Redux DevTools on every start, having read an unpackaged Electron as a development environment. Harmless while userData died with the container, fatal once it persists (obstacle #10) | the loader refuses those extensions by id, and logs any other extension load instead of silently allowing it |

Note the shape of both: invisible in development, certain in production. One
came from a configuration difference (no bridge), the other from a lifecycle
difference (state that now survives). Packaging exposed them, not coding.

### Debian packaging

Following the Debian developers' reference, plus one thing it does not cover.

**Dependencies were unsatisfiable on the target machine.** Six libraries were
declared under names that no longer exist on Ubuntu 24.04, renamed by the
`t64` transition (`libasound2` → `libasound2t64`, likewise `libatk1.0-0`,
`libatk-bridge2.0-0`, `libcups2`, `libgtk-3-0`), and `p7zip-full` has been
replaced by `7zip`. Each is now declared as an alternative
(`libasound2t64 | libasound2`) so the package installs on both current Ubuntu
and stable Debian. Verified with `apt-get install -s`.

**From the reference itself:**

- The synopsis is a phrase, not a sentence: no leading article, no final full
  stop, around 50 characters.
- The extended description is full sentences whose first paragraph answers what
  the package does and what task it helps with, so it opens by explaining what
  Granola is, since the reader may not know. It contains no question, which the
  reference forbids outright.
- Maintainer scripts "must be idempotent", and removal, double installation and
  purge all have to be tested. A `postrm` was missing entirely: without it the
  `granola://` registration kept pointing at an uninstalled package. Neither
  script creates a file, so purge is clean by construction.
- `desktop-file-utils` moved from `Suggests` to `Recommends`: without it the
  scheme handler is never registered and signing in needs a manual step again.

**Not shipped, taken from the user's own copy:** the icon. The `.desktop` entry
names one the package has no right to distribute, so the launcher lifts
`granola_app_icon-*.png` out of the extracted app on first run (the asset name
carries a content hash, hence the glob).

**Two more failures surfaced by the first real install:**

| # | Symptom | Cause | Fix |
|---|---|---|---|
| 13 | `exec: /tmp/pkg/opt/.../asar: not found` | the heredoc generating `asar-extract` was unquoted, so `$PREFIX` expanded at build time and the staging path was written into the shipped script | quoted heredoc holding the installed prefix |
| 14 | (would have followed) asar needs `node` on `$PATH` | it ships a `#!/usr/bin/env node` script; on this machine Node comes from mise and is absent from a plain shell, a `.deb` must not require it | run it through the bundled Electron with `ELECTRON_RUN_AS_NODE=1` |

The launcher also stopped trying an asar inside Electron that never existed,
whose failure was swallowed by `2>/dev/null`, the redirect that would have
hidden #14 had it appeared alone.

### Validated end to end (2026-07-31)

```
app extracted -> installing the Linux sqlite module
single-instance-lock-acquired
google_login_clicked -> rewrote platform=linux -> macos -> browser
second-instance argv: [... "granola://login-complete?code=..."]
granola-url-handled {"type":"login-complete"} -> login_completed
auth-electron-set-tokens -> auth-electron-set-user-info -> homescreen_viewed
```

Signing in needs **no manual step** from the package: the browser returns the
callback through the registered scheme handler, and the app takes it off argv
via its single-instance handler.

**Do not test deep links against a live session.** Delivering a made-up
`granola://login-complete?code=test123` to a signed-in app makes the backend
answer `400 Invalid authorization grant`, and the app signs the user out.

## Phase 4, meeting auto-detection

Granola knows a call started by watching **which applications hold the
microphone**. The pipeline, read out of the bundle:

```
platform monitor  ->  callback([{bundleId, pid, deviceUID}])  ->  FTt()
                                                                   |
                              meeting-apps log, setMicApps dispatch, mute sync
```

Two facts made this tractable:

- **The contract is one function.** `subscribe(callback) -> unsubscribe`. The
  macOS helper is just as small: it requires its native module from
  `process.argv[2]` and calls `getActiveInputProcesses()` on a 1 s timer,
  posting only when the set changes.
- **Bundle identifiers are the currency on every platform.** The Windows
  monitor does not invent its own names, it maps `chrome.exe` to
  `com.google.Chrome`, `ms-teams.exe` to `com.microsoft.teams2`. So a Linux
  monitor maps executables onto the same identifiers and everything downstream
  works unchanged.

**The blocker was the platform switch**, which hands Linux a dead arm:

```js
process.platform === `darwin` ? … : process.platform === `win32` ? … :
    e => (e([]), () => {})      // reports "nobody" once, then gives up
```

Since the callback never fires again, the app cannot learn anything.

**What was rejected.** Spoofing `process.platform = 'darwin'` is a two-line
change and a bad one: the value is read across dozens of branches, native
module path resolution, the TCC permission gate, the `platform` value sent to
`/v1/auth`, so it risks regressing login and audio, which work today.
Dispatching `setMicApps` into their store directly skips the other things
`FTt()` does (mute sync among them) and would rot against every release.

**What was done.** `loader.js` rewrites that one arm **in memory** before
compiling main, pointing it at `stubs/mic-monitor-linux.js`. The file on disk is
never touched, so a Granola update simply replaces it. The pattern is anchored
on the `win32` ternary and verified to match exactly once; if a future build
changes shape it stops matching, the app loads verbatim, and only
auto-detection disappears. `GRANOLA_MIC_MONITOR=0` skips it.

**The monitor** polls `pw-dump` (from `pipewire-bin`) once a second. Capture
streams are nodes with `media.class = Stream/Input/Audio`; the node names the
application but the pid lives on the **client** it belongs to, joined through
`client.id`, where `application.process.binary` and `application.process.id`
are. Binaries are mapped onto Apple bundle ids, Granola's own processes are
excluded by walking `/proc/<pid>/stat` up the parent chain (otherwise its own
recording would look like a meeting), and the callback fires only when the set
of applications changes.

## Open questions

1. **`granola.node` contract**, method names, arguments, audio buffer layout.
   `stubs/modules/granola.js` logs every call to reveal it at runtime. This is
   the whole of Phase 2: audio capture via PipeWire.
2. **Where diarisation runs**, locally (`speaker_embedding_process`) or server-side.
3. **`meet-consent-host`**, a native messaging host the app installs for its
   Chrome extensions. Needs a Linux replacement (or a clean disable) in Phase 2.
4. **Registering `granola://` on the host**, a `.desktop` entry with
   `MimeType=x-scheme-handler/granola` would let the browser hand the callback
   back automatically, removing the copy-paste step. Belongs in the `.deb`
   (which owns host integration); the container flow keeps using
   `scripts/deliver-callback.sh`.

### Answered

- **Backend attestation**, *yes, the server accepts a non-official client.*
  Full login and sync completed from the container on 2026-07-31.
