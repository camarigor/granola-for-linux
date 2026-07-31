# granola-for-linux

Run the **Granola** meeting notepad on Linux. Recording, live transcription,
automatic notes, calendar sync and meeting auto-detection all work.

Granola ships for macOS and Windows only. This project makes the macOS build
run on Linux, using **your own copy** of the app.

## Why

Every few months another AI product launches, and the download page offers
macOS and Windows. Linux gets a shrug, a "coming soon" that never arrives, or a
web app with half the features. The engineers building these tools very often
develop on Linux themselves, so the exclusion is a product decision rather than
a technical one.

It is especially galling with Electron apps. Electron **is** Chromium plus
Node, and both run on Linux natively. When a company ships an Electron app for
two platforms and not the third, nothing is blocking them. They simply decided
we are not worth a build target.

Granola turned out to prove that point precisely. Its product logic is
JavaScript and platform agnostic. What is macOS specific are a handful of
native modules, and a Windows layer **already exists** in the same bundle:

| Signal in v7.452.1 | Value | Reading |
|:--|:--|:--|
| `process.platform` in the main bundle | 229 occurrences | platform specific logic is extensive |
| `darwin` / `win32` / `linux` strings | 142 / **124** / 19 | a Windows layer is already there |
| native modules | 15, all Mach-O | need Linux equivalents or stubs |

So porting was never "rewrite the product". It was writing the third
implementation of a native layer that already had two. As it turned out, most
of it was not needed at all, because the app has a browser based audio capture
path that covers both the microphone and system audio.

This is what one person plus an afternoon of reverse engineering produced. A
company with a payroll could have done it in a sprint.

## What this does to Granola, please read

**No Granola code, binary or asset is in this repository, and none is
redistributed.** You supply the official `.dmg`, downloaded from granola.ai by
you. Everything here is our own code.

That said, **this does modify how Granola runs**, and you should know exactly
how before you trust it with your meetings.

| What | Where | Why |
|:--|:--|:--|
| Native module loads are intercepted | in memory, at runtime | the macOS `.node` files cannot load on Linux, so JavaScript stand ins take their place |
| `resourcesPath`, `getAppPath`, the app name and version are redirected | in memory | an unpackaged Electron reports its own paths, and the app would look for its assets in the wrong place |
| The `app://` protocol handler serves from disk | in memory | the app's own handler uses a fetch that Chromium refuses here |
| **One expression in the main bundle is rewritten** | in memory, before execution | the platform switch hands Linux a dead arm, so meeting auto-detection could never run. See "How it works" below |
| **The SQLite module is replaced** | on disk, in *your extracted copy* | the bundled one is a macOS binary, and ours is built for Linux with the two compile time features Granola's private fork relies on |

The `.dmg` you downloaded is never touched. The extracted copy under
`~/.local/share/granola-for-linux/` is yours, and the SQLite swap happens
there. Every other change lives in memory for the lifetime of the process, so a
Granola update simply replaces the files and the port keeps working.

**This is unofficial.** Granola Labs does not support it, has not endorsed it,
and owes you nothing if it breaks. If something misbehaves, reproduce it on
macOS before reporting it to them, because it is far more likely to be our
problem than theirs.

## Status

| Feature | State |
|:--|:--|
| App launches, UI renders | works |
| Sign in with Google | works, no manual step |
| Sign in with Microsoft | works, no manual step |
| Calendar sync, note sync | works |
| Recording (microphone and system audio) | works |
| Live transcription | works |
| Automatic note generation | works |
| Meeting auto-detection | works, needs `pipewire-bin` |
| Google Meet consent overlay | **not available**, needs a macOS helper binary |

Tested on Ubuntu 24.04 with Granola 7.452.1 and Electron 42.7.0.

Every obstacle met along the way, with its cause and fix, is written up in
[`docs/findings.md`](docs/findings.md).

## Install, the recommended path

### 1. Get the package

Download `granola-for-linux_*_amd64.deb` from the releases page, or build it
yourself (see [Building](#building-the-package-yourself)).

### 2. Install it

```bash
sudo apt install ./granola-for-linux_0.1.0_amd64.deb
```

If apt complains that its `_apt` user cannot read the file, your home directory
is not world traversable. That is normal and harmless, but to keep the output
clean:

```bash
cp granola-for-linux_0.1.0_amd64.deb /tmp/
sudo apt install /tmp/granola-for-linux_0.1.0_amd64.deb
```

Dependencies come from your distribution. `pipewire-bin` is a `Recommends`,
because it provides `pw-dump`, which meeting auto-detection reads. Without it
everything else still works and you start recordings by hand.

### 3. Point it at your Granola download

Download the macOS `.dmg` from <https://www.granola.ai/download>, then:

```bash
granola-for-linux ~/Downloads/"Granola - AI Notepad.dmg"
```

This unpacks the app into `~/.local/share/granola-for-linux/app-src`, installs
the Linux SQLite module into it, lifts the application icon out of it, and
launches.

### 4. From then on

```bash
granola-for-linux
```

or the **Granola (Linux)** entry in your application menu.

### Signing in

Click sign in, complete it in the browser that opens, and you are done. The
package registers `x-scheme-handler/granola`, so the OAuth callback comes back
to the app by itself. Google and Microsoft both work.

Your browser will ask whether to open "Granola (Linux)". That prompt *is* the
callback arriving. Allow it.

### Updating Granola

Download the new `.dmg` and pass it in again:

```bash
granola-for-linux ~/Downloads/"Granola - AI Notepad.dmg"
```

Passing a `.dmg` always re extracts. The new tree is unpacked alongside the old
one and swapped in at the end, so an interrupted update cannot leave a broken
install, and the Linux SQLite module reinstalls itself. Your notes, settings
and session are untouched, because they live in `~/.config/Granola` rather than
in the app.

Updating this project (new fixes) is an ordinary
`sudo apt install ./granola-for-linux_*.deb`, and does not disturb the
extracted app.

### Where things live

| Path | Contents |
|:--|:--|
| `/opt/granola-for-linux/` | Electron, our stubs, the Linux SQLite module |
| `~/.local/share/granola-for-linux/app-src/` | Granola, extracted from your `.dmg` |
| `~/.config/Granola/` | your notes, tokens and settings |

Removing the package leaves the last two in place. Delete them by hand if you
want them gone.

## Run with Docker

The container needs no installation on the host beyond Docker itself, because
Electron, Node and the toolchain all live in the image. This is how the port
was developed, and it is useful for trying things without touching your system.

Note that the container is the **development** environment. Signing in needs
one manual step there, because a browser on the host cannot hand a `granola://`
callback into a container.

### 1. Get the image

Pull the published image:

```bash
docker pull ghcr.io/camarigor/granola-for-linux:latest
docker tag ghcr.io/camarigor/granola-for-linux:latest granola-for-linux:dev
```

Or build it. Electron and the SQLite module are compiled inside, which takes a
few minutes:

```bash
git clone https://github.com/camarigor/granola-for-linux
cd granola-for-linux
./scripts/build-env.sh
```

### 2. Extract your `.dmg`

```bash
./scripts/extract.sh ~/Downloads/"Granola - AI Notepad.dmg"
```

Unpacks into `work/app-src/`, which is never versioned. Needs `7z` on the host
(`sudo apt install 7zip`).

Optionally, survey what the bundle contains:

```bash
./scripts/analyze.sh
```

### 3. Run

```bash
./scripts/run.sh
```

The window opens on your X11 display. The script wires up, into the container:
the X11 socket, PulseAudio, PipeWire, `/dev/dri` for GPU acceleration, the
extracted app, our stubs, and `work/app-data` as persistent storage so your
session survives restarts.

Useful switches:

| Variable | Effect |
|:--|:--|
| `GRANOLA_STUB_VERBOSE=0` | quieten our own log lines |
| `GRANOLA_TRACE_CONSOLE=0` | do not expand the app's log objects over the DevTools protocol |
| `GRANOLA_MIC_MONITOR=0` | leave meeting auto-detection out |
| `GRANOLA_DEVTOOLS=1` | allow React and Redux DevTools to load (they hang startup, see findings) |

### 4. Sign in, container only

The app opens the auth URL in your real browser through a bridge. When the
browser lands on **"Opening Granola..."**, copy the address bar and hand it
over, *while the app is still waiting on its sign in screen*:

```bash
./scripts/deliver-callback.sh 'https://www.granola.ai/app-redirect?code=...'
```

Three rules, each learned the hard way:

* **One tab per sign in.** A second concurrent flow makes Google fail with
  "Something went wrong".
* **Finish within 15 minutes.** The auth `state` is a JWT with a 900 second
  lifetime, and after that WorkOS answers "Invalid state".
* **Do not close or restart the app** in between, because the callback is only
  accepted while the app sits on `/login-in-progress`.

Install the `.deb` and none of this applies, since the scheme handler does it
for you.

### Building the package yourself

```bash
./packaging/build-deb.sh
```

Runs entirely in a container and writes `dist/granola-for-linux_*_amd64.deb`.
It compiles the SQLite module with the same recipe the image uses
(`scripts/build-sqlite.sh`), so the two can never drift.

## How it works

`stubs/loader.js` is launched instead of the app, and prepares the ground
before handing over.

**Native modules.** It replaces Node's `.node` loader. Requires for Granola's
macOS modules resolve to JavaScript stand ins in `stubs/modules/`, while
genuine third party natives get a Linux build. An unknown module returns a
proxy that throws a descriptive error on use, so one run reveals everything
missing rather than dying at the first.

**Identity and paths.** An unpackaged Electron calls itself "Electron" and
points `resourcesPath` at its own directory. The loader adopts the app's real
name and version from its `package.json`, so settings land in
`~/.config/Granola` rather than a directory shared with every other unpackaged
Electron app.

**Assets.** The app serves its UI over an `app://` protocol using a fetch that
Chromium refuses here. The loader serves those files from disk first.

**Sign in.** `api.granola.ai/v1/auth` answers HTTP 500 for any `platform` other
than `macos` or `windows`. Both `linux` and even `darwin` fail, so the loader
rewrites the value. We are running the genuine macOS bundle, so this is
accurate rather than a lie. In the container it also bridges the URL out to the
host browser and the callback back in.

**SQLite.** Granola ships a private fork of `better-sqlite3-multiple-ciphers`
whose two extras are its reactive data layer: `tables_used()`, a table valued
function needing `SQLITE_ENABLE_BYTECODE_VTAB` at compile time, and
`updateHook()`, which no public version has. Ours is compiled with the flag,
and `stubs/sqlite-updatehook-shim.js` implements the hook for real, so writes
report their tables through `tables_used()`. Without it the app runs on stale
reads and generating notes fails with a 404.

**Meeting auto-detection.** Granola notices a call by watching which
applications hold the microphone. The platform switch hands Linux an arm that
reports "nobody" once and gives up, so the loader rewrites that one expression
in memory to point at `stubs/mic-monitor-linux.js`, which polls `pw-dump` and
maps Linux executables onto the Apple bundle identifiers the app expects. That
is the same thing the bundle's own Windows monitor does with `chrome.exe`.

The rewrite is anchored on a pattern verified to match exactly once. If a
future Granola changes shape, it stops matching, the app loads verbatim, and
only auto-detection is lost. Nothing fails silently.

## Layout

```
scripts/     extraction, analysis, container build and run, callback delivery
packaging/   .deb: launcher, desktop entry, control, maintainer scripts, build
stubs/       loader, JS replacements for the macOS natives, sqlite shim,
             PipeWire microphone monitor
docs/        reverse engineering findings: every obstacle, cause and fix
work/        (ignored) your extracted app and its data
dist/        (ignored) the built .deb
```

## Troubleshooting

**The app opens but nothing happens when I click sign in.** An instance is
probably already running. It holds a single instance lock, and later launches
exit quietly. Check with `pgrep -af granola-for-linux`.

**The browser says it cannot open `granola://`.** The scheme handler is not
registered. Reinstall the package, or run
`update-desktop-database ~/.local/share/applications`.

**Meeting auto-detection never fires.** Install `pipewire-bin` and confirm
`pw-dump` runs. Start from a terminal with `GRANOLA_STUB_VERBOSE=1` and look
for `meeting auto-detection: PipeWire monitor injected` on startup.

**No icon in my launcher.** It is lifted from the extracted app on first run
into `~/.local/share/icons/hicolor/512x512/apps/`. If you installed before that
was added, run once with the `.dmg` again.

**Sign in fails with "Invalid state".** The auth token expired, because a tab
was left sitting for over 15 minutes. Start again.

## Licence

Code in this repository is MIT. That covers our code only.

Granola is the property of Granola Labs, Inc., is not licensed to us or to you
by this repository, and is not distributed here. You need your own copy and
your own account, and your use of it is governed by their terms.
