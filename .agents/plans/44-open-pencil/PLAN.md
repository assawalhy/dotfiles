# Plan: OpenPencil as a self-updating AppImage

**Status: implemented, awaiting the user's launch check.** Drafted, approved and
executed 2026-10-21 as a Nix package, then switched to the user-space AppImage on
2026-10-22 so the app's own updater works. The AppImage then refused to start with
`Unable to establish IDB database file`; the cause is diagnosed and the repair is
recorded as D9 below. Progress is in [TODO.md](TODO.md).

## Goal

Install the OpenPencil desktop app, release v0.16.0, in a shape that lets its own
Software Update window work.

## Findings (verified 2026-10-21)

1. **Not in nixpkgs.** `pkgs/by-name/op/` in both `nixos-26.05` (the channel this
   machine runs) and `nixos-unstable` has no `open-pencil`, and a code search for
   `open-pencil` and `openpencil` across `NixOS/nixpkgs` returns 0 hits. The
   project's own repo has no `flake.nix`. The package has to be local to this
   repo.
2. **Linux assets.** v0.16.0 publishes `OpenPencil_0.16.0_amd64.AppImage`
   (96 MB), `OpenPencil_0.16.0_amd64.deb` (18.8 MB) and
   `OpenPencil-0.16.0-1.x86_64.rpm` (18.8 MB), plus `SHA256SUMS`. There is no
   arm64 Linux build.
3. **The .deb is small and self-describing.** `Package: open-pencil`,
   `Depends: libwebkit2gtk-4.1-0, libgtk-3-0`. Its data tarball holds exactly
   three things: `usr/bin/OpenPencil` (41.9 MB, mode 0755), hicolor icons at 32,
   128 and 256 px, and `usr/share/applications/OpenPencil.desktop`
   (`Exec=OpenPencil %U`, `StartupWMClass=OpenPencil`,
   `MimeType=application/x-pencil-pen;application/x-figma;x-scheme-handler/openpencil`,
   `Categories=` empty).
4. **The binary's NEEDED list** is `libwebkit2gtk-4.1.so.0`,
   `libjavascriptcoregtk-4.1.so.0`, `libsoup-3.0.so.0`, `libgtk-3.so.0`,
   `libgdk-3.so.0`, `libgdk_pixbuf-2.0.so.0`, `libcairo.so.2`,
   `libgobject-2.0.so.0`, `libglib-2.0.so.0`, `libgio-2.0.so.0`,
   `libdbus-1.so.3`, `libfontconfig.so.1`, plus libc, libm and libgcc. All are
   reachable from `webkitgtk_4_1` and `gtk3` in nixpkgs 26.05.
5. **The frontend is embedded in the binary**, so nothing else needs shipping.
   The Tauri updater is compiled in: the binary carries
   `https://github.com/open-pencil/open-pencil/releases/latest/download/latest.json`,
   `requireSignedVersion`, and `__TAURI_BUNDLE_TYPE_VAR_DEB`.
6. **Telemetry knobs**: the binary reads `OPENPENCIL_TELEMETRY` and
   `DO_NOT_TRACK`; the 0.16.0 notes say one anonymous ping a day that
   `DO_NOT_TRACK=1` turns off.
7. **Repo precedent**: `nix/claude-desktop/` packages Anthropic's official Linux
   .deb with `dpkg` + `autoPatchelfHook` + `wrapGAppsHook3`, keeps a
   `update.sh` bump script, and adds the package to `environment.systemPackages`
   in `nix/configuration.nix`. The same shape fits here, without the asar
   patching.
8. **Hash**: the `amd64.deb` sha256 in the release's own `SHA256SUMS` is
   `451e90efd4607f528ff5e705dfc6f6193eaeef222c33aa69ebfbd863d170bd73`,
   which is `sha256-RR6Q79Rgf1KP9ecF38b2GT6u7yIsM6pp6/vYY9FwvXM=`.

## Findings (verified 2026-10-22, the AppImage switch)

9. **The updater's Linux payload is the AppImage.** The endpoint the binary
   carries, `releases/latest/download/latest.json`, lists
   `linux-x86_64` → `OpenPencil_0.16.0_amd64.AppImage` with its signature, plus
   separate `-appimage`, `-deb` and `-rpm` keys.
10. **The deb build updates through a package manager.** Its binary carries
    `__TAURI_BUNDLE_TYPE_VAR_DEB` and the updater strings `pkexec`, `-i -U`,
    `Enter your password to install the update:` and
    `Failed to install .deb package`. On NixOS that path has no read-only store
    to write and no dpkg or apt behind pkexec, so a store install cannot update.
11. **The AppImage build rewrites its own file.** The same binary carries
    `tauri_plugin_updater::updater::install_appimage`, `rewriting AppImage`,
    `current_app.AppImage`, and the `APPDIR`/`APPIMAGE` detection. It writes the
    new AppImage beside the current one and renames it, so the directory holding
    it must be writable.
12. **`appimage-run` hands the app the real AppImage path.** nixpkgs'
    `appimage-exec.sh` runs `APPIMAGE="$(realpath "$1")"` and `export APPIMAGE`
    before `exec "$APPDIR/AppRun"`, so the app sees
    `~/Applications/open-pencil.AppImage`. That is the mechanism that already
    lets opencode-desktop (2.0.22 → 2.0.24) and Orca update themselves here.
13. **Repo rule.** `.agents/plans/21-self-updating-apps` D1 and D4 decided that an
    app with its own updater lives in user-writable space, never in the store,
    and `setup/steps/71-opencode-desktop.sh` repeats it: "Do NOT repackage this
    into the Nix store, that is what breaks auto-update". The store package this
    plan first built contradicts that rule.
14. **The app registers a scheme handler at launch.** Running the store build
    wrote `~/.local/share/applications/.openpencil-wrapped-handler.desktop`, with
    `Exec` pointing at the wrapped binary name (`bin/.openpencil-wrapped`) for
    `x-scheme-handler/openpencil`, and `./link-files.bash --audit` reported it as
    `[unlinked]`. The name is an artifact of `wrapGAppsHook3`, and the app
    rewrites the file on every launch.

## Findings (verified 2026-10-22, the IndexedDB failure)

15. **The AppImage brings its own WebKitGTK and SQLite, and uses them.** The
    running process loads `././/lib/x86_64-linux-gnu/webkit2gtk-4.1/WebKitNetworkProcess`
    and `WebKitWebProcess` from the AppImage, so the bundled libraries win over the
    system's. The bundle is an Ubuntu 22.04 set: `libwebkit2gtk-4.1` 2.44.4 and
    `libsqlite3` 3.37.2 (the extracted tree lists jammy package names such as
    `libicu70`, `libtiff5`, `libunwind8`).
16. **The two WebKit generations disagree on the IndexedDB on-disk format.**
    WebKit 2.44.4 has `currentMetadataVersion = 1` and reads the stored database
    name with `columnText`; WebKit 2.52.6, which nixpkgs builds and the store
    package used, has `currentMetadataVersion = 2` and stores that name as a
    UTF-16LE BLOB.
17. **The store package wrote three databases in the new format.** The launch test
    at 2026-10-22 00:50 created `open-pencil-cloud-outbox` (store `jobs`),
    `open-pencil-cloud-local` (stores `fig`, `meta`, `thumb`) and
    `open-pencil-recovery` (stores `fig`, `meta`) in
    `~/.local/share/net.dannote.open-pencil/databases/indexeddb/v1/tauri_localhost_0/`,
    all with `MetadataVersion = 2` and BLOB names. The AppImage's own databases,
    `open-pencil-chats` and `open-pencil-diagnostics`, are `MetadataVersion = 1`
    with TEXT names.
18. **The failure path is in 2.44.4's source.** `extractExistingDatabaseInfo`
    (lines 773 to 786) reads the name with `columnText`, gets the BLOB bytes, sees
    a mismatch with the requested name and returns nullptr. The caller then runs
    `createAndPopulateInitialDatabaseInfo` on a file that already holds the
    schema, the `CREATE TABLE IDBDatabaseInfo` fails, and
    `getOrEstablishDatabaseInfo` (lines 1025 to 1035) returns `UnknownError` with
    `Unable to establish IDB database file`. The 2.52.6 source (lines 992 to 1017)
    cannot reach that state because it reads the name as a BLOB and migrates a v1
    database upward. The strings `Metadata versions match, but stored database
    name does not match requested name` and `will upgrade again` are present in the
    system library and absent from the bundled one, which dates the bundle before
    the v2 change.
19. **It is not a SQLite problem.** Loading the bundled `libsqlite3` 3.37.2 through
    ctypes opens all five databases and reads both `MetadataVersion` and the table
    list, so the old SQLite reads the new files without complaint.
20. **The three affected databases are empty.** Every object store in them reports
    0 records. The app's own stores are the v1 pair, and `open-pencil-chats`
    reports 0 records as well, so nothing is lost by recreating the three.

## Decision (revised 2026-10-22)

**D8 supersedes D1 to D7: install the official AppImage under `~/Applications`
and drop the store package.** The app's own updater then works, which is what
this app is installed for, and it follows epic 21's rule.

- `setup/steps/72-open-pencil.sh` resolves the latest release tag, downloads
  `OpenPencil_<ver>_amd64.AppImage` to `~/Applications/open-pencil.AppImage`
  under a stable name (skipped when present, because the app updates itself),
  extracts the icon from the AppImage, and prints what it did. Shape copied from
  `setup/steps/71-opencode-desktop.sh`.
- `common/.local/share/applications/open-pencil.desktop` is committed and linked
  by `link-files`, with `Exec=sh -c 'exec "$HOME/Applications/open-pencil.AppImage" "$@"' open-pencil %U`,
  matching `orca-ide.desktop`. On NixOS the exec goes through binfmt to
  `appimage-run`, which is also what sets `APPIMAGE` for the updater.
- `nix/open-pencil/default.nix`, `nix/open-pencil/update.sh` and the
  `configuration.nix` entry are removed. Nothing was ever activated, so no switch
  is needed to undo it.
- The leftover `.openpencil-wrapped-handler.desktop` is deleted.

**D9: repair the shared IndexedDB directory and keep the AppImage the only
writer.** The three databases that the store package wrote in the v2 format cannot
be opened by the AppImage's WebKit 2.44.4, and they are empty, so they are moved
out of the tree into `databases/indexeddb/v1-incompatible-20261022/` and the
AppImage recreates them in its own format on the next launch. Nothing else in the
data directory is touched. The rule that follows: never run the store package
against the real data directory, and when it is tested, point `XDG_DATA_HOME` at a
scratch directory.

### Superseded decisions (the store package, 2026-10-21)

Kept for the record: D1 packaged the official .deb; D2 built it with `dpkg` +
`autoPatchelfHook` + `wrapGAppsHook3`, installed as `$out/bin/openpencil`; D3 set
`Categories=Graphics;`; D4 set `DO_NOT_TRACK=1` and added `xdg-utils` to `PATH`;
D5 added `update.sh`; D6 added it to `environment.systemPackages`; D7 left the
Tauri updater alone as unusable. D3 and D4 carry over to the desktop entry in the
new route.

### Rejected alternatives

- **Keep the store package.** Verified working end to end (build, launch, toplevel
  closure), but its updater is the deb path, so every version needs
  `update.sh` plus a switch, and the scheme-handler file needs a
  `link-ignore.txt` entry. Rejected in favour of the app's own update path.
- **The AppImage plus the store package.** Two installs of one app, two app-grid
  entries, and a duplicate 100 MB payload. Rejected.
- **Build from source.** Tauri 2 + bun + wasm canvas toolchain, unpinned, and
  this repo already has one build-from-source casualty (`megasync`, deferred for
  long-clone failures).
- **The rpm.** Same payload as the deb, and the same unusable updater path.
- **Convert the three databases in place to the v1 format.** Rewriting the name as
  TEXT and `MetadataVersion` to 1 would preserve them, and the table schemas are
  identical across the two versions, but they hold no records, so the conversion
  buys nothing over recreating them.
- **Force the AppImage to use the system WebKit 2.52.6.** `AppRun` prepends its own
  library directory, so the bundled library wins; overriding it needs `LD_PRELOAD`
  plus `WEBKIT_EXEC_PATH` surgery that the next AppImage update undoes. Rejected as
  fragile, not as impossible.
- **Give open-pencil its own `XDG_DATA_HOME`.** It splits the app's data from the
  rest of the system, and it still would not stop a second build from writing the
  same tree.

## Changes

1. `setup/steps/72-open-pencil.sh` (new).
2. `common/.local/share/applications/open-pencil.desktop` (new, linked by
   `link-files --fix`).
3. `nix/open-pencil/default.nix`, `nix/open-pencil/update.sh`: deleted.
4. `nix/configuration.nix`: the `callPackage ./open-pencil { }` line removed.
5. `~/.local/share/applications/.openpencil-wrapped-handler.desktop`: deleted.
6. `~/.local/share/net.dannote.open-pencil/databases/indexeddb/v1-incompatible-20261022/`
   (new, holds the three moved databases), and the three database directories the
   AppImage recreates on the next launch.

## Verification

1. `bash -n setup/steps/72-open-pencil.sh` passes.
2. The step installs `~/Applications/open-pencil.AppImage` and the icon, and a
   second run leaves the AppImage alone.
3. The AppImage starts on this session's display through binfmt and
   `appimage-run`.
4. `APPIMAGE` reaches the app: read `/proc/<pid>/environ` of the running process
   and find `APPIMAGE=/home/assawalhy/Applications/open-pencil.AppImage`.
5. `~/Applications` is writable, and the AppImage file is not read-only, so the
   updater can rename over it.
6. `./link-files.bash --fix` links the desktop entry, and the entry resolves to a
   real Exec.
7. `./link-files.bash --audit` findings drop back to the 29 that predate this
   work (no `.openpencil-wrapped-handler.desktop`).
8. User check: OpenPencil starts from the app grid, and its Software Update
   window reports the current version instead of an install failure.
9. After the D9 repair, the AppImage starts without the error screen, and
   `open-pencil-cloud-outbox`, `open-pencil-cloud-local` and `open-pencil-recovery`
   reappear with `MetadataVersion = 1` and TEXT names.
10. `open-pencil-diagnostics` gains no new record whose message is
    `Unable to establish IDB database file`.

## Risks

- **An update cannot be proven until 0.17.0 ships.** What is proven: the release
  metadata offers the AppImage to the `linux-x86_64` target, the updater's
  AppImage install path is in the binary, `APPIMAGE` reaches the app, and the
  target directory is writable.
- **Disk cost.** A 96 MB download plus roughly 250 to 300 MB extracted per
  version under `~/.cache/appimage-run`, which already holds 1.5 GB.
- **No store integration.** The desktop entry and the icon are user space, and
  the icon is extracted at install time, so a fresh machine needs the step.
- **The scheme handler points into the extraction cache.** The app writes
  `x-scheme-handler/openpencil` with the running binary's path, which under
  `appimage-run` is `~/.cache/appimage-run/<sha>/AppRun` and therefore changes
  with every version. The app rewrites it on the next launch, and the committed
  desktop entry declares the same scheme with a stable Exec.
- **`--appimage-extract` with a pattern is refused** by this repo's binfmt
  wrapper (epic 42), so the icon extraction uses the no-pattern form and picks
  the file out of the extracted tree.
- **Binary release, not a source build.** The step installs upstream's signed
  release artifact and pins no version, so a fresh machine takes whatever is
  latest. The version it prints is the record.
- **amd64 only.** The release has no arm64 Linux build, so the step is
  x86_64-linux only.
- **WebKitGTK's DMABUF renderer often fails on NVIDIA hybrid setups**, which
  shows as a blank window. This box is Intel + NVIDIA. The store build's 20 s
  launch test on 2026-10-21 produced no DMABUF, EGL or renderer error, so nothing
  is set; if a blank window shows up, the fix is
  `WEBKIT_DISABLE_DMABUF_RENDERER=1` in the desktop entry's Exec.
- **Links need the system `xdg-open`.** The AppImage no longer bundles it; the
  session has `xdg-utils` at `/run/current-system/sw/bin/xdg-open`.
- **Double-click association for `.fig` and `.pen` files is out of scope.** The
  desktop entry declares the MIME types, but NixOS default-app wiring for them is
  a separate change.
- **The bundle ships an old engine and an old SQLite.** WebKitGTK 2.44.4 (2024) and
  SQLite 3.37.2 (2022) come from the AppImage, not from nixpkgs, so this system
  patches neither. The store package used the patched 2.52.6 but cannot update
  itself. That is the cost the AppImage route pays for self-update, and the store
  package stays available in the old generation for a one-off run against a scratch
  data directory.
- **The failure returns if a newer WebKit writes that data directory again**, for
  example a future AppImage update that migrates the v1 databases upward, followed
  by a rollback to 0.16.0. The recovery is the same as D9.
