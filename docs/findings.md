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

### State at the end of Phase 1

With all of the above applied, the app boots and the **UI renders** (Granola's
own error screen is drawn, with correct typography, icons and buttons). The log
shows the full startup chain succeeding:

```
app-started {"wasFirstLaunch":true}      primary-window-created
sqlite-init-success                      sqlite-migrate-success
websocket-network-online-detected        window-opened
```

**No native stub has been called yet**, the UI mounts without touching the
macOS modules. They should only come into play at login and, above all, when
recording (Phase 2).

## Open questions

1. **`sqlite-exec-error`**, the current blocker. SQLite initialises and migrates,
   but one statement fails and the React error boundary shows "Something went
   wrong". Likely tied to the same fork that provides `updateHook`. The renderer
   error listeners in `loader.js` are installed to surface the real exception.
2. **`granola.node` contract**, method names, arguments, audio buffer layout.
   `stubs/modules/granola.js` logs every call to reveal it at runtime.
3. **Backend attestation**, will the server accept a non-official client? Still
   unanswered: the app has not reached a successful login yet.
4. **Where diarisation runs**, locally (`speaker_embedding_process`) or server-side.
