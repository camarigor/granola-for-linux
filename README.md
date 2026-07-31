# granola-for-linux

Running the **Granola** client (macOS, Electron) on Linux.

> **This repository contains no Granola code, binaries or assets.**
> The app is proprietary. The scripts here extract **your own copy** from the
> official `.dmg`, on your machine, and patch it at runtime. Nothing from the
> app is redistributed, and the bundle itself is never modified.

## Why this is feasible (and where it stalls)

Granola is an Electron app, so the product logic is JavaScript and runs
anywhere. What is macOS-specific are **15 native modules** (`.node`, Mach-O,
closed source) under `Contents/Resources/native/`.

Survey of v7.452.1 (see `docs/findings.md`):

| Signal | Value | Reading |
|---|---|---|
| `process.platform` in main | 229 occurrences | platform-specific logic is extensive |
| `darwin` / `win32` / `linux` strings | 142 / **124** / 19 | **a Windows layer already exists**, the architecture is cross-platform |
| native modules | 15 (all Mach-O) | need a Linux equivalent or a stub |
| audio capture | ScreenCaptureKit + CoreAudio + AVFoundation | the only genuinely hard part |

In other words: porting is **not** rewriting the product, it is writing the
third implementation of the native layer (macOS → Windows → Linux).

## Status

**Phase 1 (app boots), done.** The window opens, the UI renders, SQLite
initialises and migrates, and the app reaches its login screen with no errors.

**Phase 1.5 (login), done.** Google sign-in completes and the account syncs
(preferences, document lists). The backend accepts a non-official client. Two
shims make it work: the loader bridges `shell.openExternal` out to the host
browser, and re-injects the `granola://` callback the browser cannot route back.

**Phase 2 (recording), works.** Recording, live transcription and automatic
note generation all run on Linux. The app turned out to have a browser-based
capture path (`capture_method: browser`) covering both the microphone and
system audio, so porting `granola.node` was not required. Because capture
happens at the OS audio layer, Teams, Zoom and Meet are all equivalent.

**Phase 3 (packaging), done.** The `.deb` installs on Ubuntu 24.04, extracts
the app from your own `.dmg`, and **signs in with no manual step**: the browser
hands the `granola://` callback straight back through the registered scheme
handler.

**Phase 4 (meeting auto-detection), next.** A PipeWire equivalent of the macOS
monitor that reports which applications currently hold the microphone. It is
the one remaining feature that genuinely needs a `granola.node`.

See `docs/findings.md` for every obstacle, its cause and its fix.

## Requirements

- Docker (the whole toolchain runs in a container, **nothing is installed on the host**)
- `p7zip` on the host (to read the `.dmg`)
- Your own copy of `Granola - AI Notepad.dmg`

## Usage, development (container)

```bash
# 1. extract the .dmg into work/ (never versioned)
./scripts/extract.sh ~/Downloads/"Granola - AI Notepad.dmg"

# 2. map native modules and platform-specific logic
./scripts/analyze.sh

# 3. build the Electron environment
./scripts/build-env.sh

# 4. launch with stubs applied (window via the host X11)
./scripts/run.sh
```

### Signing in

`run.sh` opens auth URLs in your host browser automatically. The callback
cannot come back on its own (the host has no `granola://` handler), so hand it
over once, while the app is still waiting on its "signing in" screen:

```bash
./scripts/deliver-callback.sh '<URL from the address bar on the "Opening Granola..." page>'
```

Three rules, each learned the hard way (see `docs/findings.md`):

- **One tab per sign-in.** A second concurrent flow makes Google fail with
  "Something went wrong".
- **Within 15 minutes.** The auth `state` is a JWT with a 900 s lifetime; past
  that WorkOS answers "Invalid state".
- **Do not close or restart the app** in between, the callback is only
  accepted while the renderer sits on `/login-in-progress`.

## Usage, .deb package

```bash
./packaging/build-deb.sh          # built inside a container
sudo apt install ./dist/granola-for-linux_0.1.0_amd64.deb
granola-for-linux ~/Downloads/"Granola - AI Notepad.dmg"   # first run only
```

After the first run, `granola-for-linux` or the **Granola (Linux)** menu entry is
enough. The `.deb` ships the Electron runtime, our stubs and the Linux SQLite
module; the Granola app is extracted from your `.dmg` into
`~/.local/share/granola-for-linux/` and never goes into the package.

The SQLite module is swapped into the extracted copy on first launch (the
bundle's own is a macOS binary, and a stock Linux build would still be missing
what Granola's private fork adds). A marker file makes that re-apply by itself
whenever a newer Granola is extracted.

## Layout

```
scripts/    extraction, analysis, container build and run (development)
packaging/  .deb: launcher, desktop entry, control file, containerised build
stubs/      loader plus JS replacements for the macOS native modules
docs/       reverse-engineering findings
work/       (ignored) extracted app, your copy, never versioned
dist/       (ignored) generated .deb
```

## Design notes

- **The bundle is never patched.** `stubs/loader.js` hooks
  `Module._extensions['.node']` and injects replacements at runtime, so a
  Granola update does not undo our work, and any integrity check the app runs
  still sees an untouched bundle.
- **`granola.js` is instrumented rather than faked.** It logs every call
  (method name, argument types) and answers callbacks with silence, so running
  the app reveals the audio-capture contract needed for Phase 2.
- **Third-party natives are overridden by bind-mount**, not by copying over the
  app: the loader's require hook does not reach the renderer process, which
  loads `.node` files on its own.

## Licence

Code in this repository: MIT. This does not extend to Granola itself, which
remains the property of Granola Labs, Inc.
