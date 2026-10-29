# TODO — OpenPencil 0.16.0

Drafted and approved 2026-10-21. See [PLAN.md](PLAN.md).
Executed 2026-10-21 as a store package, then re-executed 2026-10-22 as the
user-space AppImage (D8). The AppImage route found the IndexedDB format failure,
recorded as D9 and open below.

## Store package route (superseded by D8)

- [x] `nix/open-pencil/default.nix`: deb packaging, wrapper, icons, desktop entry
      (D1, D2, D3, D4)
- [x] `nix/open-pencil/update.sh`: version and hash bump from the release
      `SHA256SUMS` (D5)
- [x] `nix/configuration.nix`: add the package next to `claude-desktop` (D6)
- [x] `nix-instantiate --parse nix/configuration.nix` is clean
- [x] package build succeeds:
      `/nix/store/a90mw9pjajq96wmd86v004cmnaq0ysiz-open-pencil-0.16.0`,
      `auto-patchelf: 0 dependencies could not be satisfied`
- [x] `ldd` resolves every NEEDED library on both the wrapper and
      `.openpencil-wrapped`; desktop entry `Exec` names the store path and
      `Categories=Graphics;`; the three icon sizes are installed
- [x] launch the built binary from the store on this session's Wayland display:
      it started, built its GTK menus and ran for the full 20 s test window with
      no error, then `timeout` killed it
- [x] `update.sh` idempotence run prints `open-pencil is already 0.16.0` and
      leaves `default.nix` unchanged
- [x] system toplevel build from the scratch mirror (ajq):
      `/nix/store/434rkcbvmk3ylax9c04vfv4l947i5avl-nixos-system-nixos-26.05.10402.1e8bc658fc98`,
      with `open-pencil` in its closure and the desktop entry linked into
      `sw/share/applications`
- [x] repo checks: `bats tests/link-files.bats` 99 ok, 0 not ok. A live
      `./link-files.bash --audit` reports 30 findings, all pre-existing under
      `.pi/agent/` and `.local/share/applications/` except one the launch test
      created: `.local/share/applications/.openpencil-wrapped-handler.desktop`
- [x] deep-link handler artifact resolved by D8: the AppImage route does not write
      `.openpencil-wrapped-handler.desktop`, and the leftover file was deleted
- [x] store package removed from `nix/configuration.nix`, so no switch is needed to
      undo it; the pending switch belongs to epic 41

## AppImage route (D8)

- [x] `setup/steps/72-open-pencil.sh` downloads the release AppImage to
      `~/Applications/open-pencil.AppImage`, extracts the icon, and is idempotent
- [x] `common/.local/share/applications/open-pencil.desktop` committed and linked
- [x] the AppImage starts through binfmt and `appimage-run`, and `APPIMAGE`
      reaches the process
- [x] `~/Applications` is writable, and the AppImage is not read-only, so the
      updater can rename over it

## IndexedDB repair (D9, open)

- [x] close OpenPencil first. It owns `net.dannote.open-pencil.SingleInstance` on
      the session bus, so a second launch only forwards to the running instance.
      It was already closed when the repair ran.
- [x] move the three v2 databases out of the tree (done; the backup holds all
      three and the origin dir now holds only the two v1 databases):
      `3E8B313DF355ADA55D2F5AE1C5908DB92A9F4897149724A3B4EDD02D3B51D07D`
      (`open-pencil-cloud-outbox`),
      `AFBB4BE381A8DF01C0E5FFF867EAF63AA0015E94A663758704D0154FC2A94D23`
      (`open-pencil-cloud-local`) and
      `CB25557B3689331B8E4BA06858096E77268A10941821DF3E539A25F71BB1F2E6`
      (`open-pencil-recovery`), from
      `~/.local/share/net.dannote.open-pencil/databases/indexeddb/v1/tauri_localhost_0/`
      to
      `~/.local/share/net.dannote.open-pencil/databases/indexeddb/v1-incompatible-20261022/`
- [x] relaunch OpenPencil: it opened its databases, restored a document, and
      recorded `editor.preparation.finished` events, with no new IDB failure
- [x] the three databases reappear with `MetadataVersion = 1` and TEXT names, and
      `open-pencil-chats` / `open-pencil-diagnostics` keep their history
- [x] `open-pencil-diagnostics` gains no new error record with that message; its
      only such record is the original one, written before the repair
- [x] keep the store package away from the real data directory: recorded as the
      standing rule in PLAN.md D9
- [ ] user: launch from the app grid and confirm the Software Update window reports
      the current version (a real update cannot be proven until 0.17.0 ships)
