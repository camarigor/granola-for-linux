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

**Phase 1 (app boots), largely working.** The window opens, the UI renders,
SQLite initialises and migrates, and the websocket connects. The app currently
stops at its own error screen, triggered by a `sqlite-exec-error`; see
`docs/findings.md` for the full chain and the next thread to pull.

**Phase 2 (recording), not started.** Requires implementing `granola.node`
for Linux (PipeWire capture) against the contract the JS expects.

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

## Usage, .deb package

```bash
./packaging/build-deb.sh          # built inside a container
sudo apt install ./dist/granola-for-linux_0.1.0_amd64.deb
granola-for-linux ~/Downloads/"Granola - AI Notepad.dmg"   # first run only
```

After the first run, `granola-for-linux` or the **Granola (Linux)** menu entry is
enough. The `.deb` ships the Electron runtime and our stubs; the Granola app is
extracted from your `.dmg` into `~/.local/share/granola-for-linux/` and never goes
into the package.

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
