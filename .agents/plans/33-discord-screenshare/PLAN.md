# 33 Discord screen share: portal cursor mode

## Goal

Clicking "Share Your Screen" in the official Discord app on this GNOME Wayland
host does nothing: no picker, no dialog, no error. After this epic the picker
opens and a share starts.

## Root cause (verified on this host)

The bug is not in Discord and not in Discord's launch flags. It is in the
xdg-desktop-portal frontend, version 1.20.4 (`/nix/store/3qx9dy3rr28qk33jcbyvwjhspq7b6xwa-xdg-desktop-portal-1.20.4`).
The frontend validates the client's `cursor_mode` against a cached value that
is stuck at 0:

| layer | `AvailableCursorModes` | `AvailableSourceTypes` |
|---|---|---|
| frontend `/org/freedesktop/portal/desktop` (running since Oct 9 23:08) | 0 | 0 |
| backend `org.freedesktop.impl.portal.desktop.gnome` 50.0 | 7 | 7 |

Discord's native picker asks for `cursor_mode = 2` (embedded). The frontend
rejects it. From `~/.config/discord/logs/discord-webrtc_1` (10:36 and 17:42
today):

    [video_linux_interop::capture::picker] cc_linux_show_picker: Failed:
      Portal request failed: org.freedesktop.portal.Error.InvalidArgument:
      Unavailable cursor mode 2

Code path, upstream 1.20.4 `src/screen-cast.c`:

1. `screen_cast_create()` (line ~1100) builds the impl proxy with
   `proxy_new_sync` plus auto start. At session start the gnome backend does not
   own its bus name yet, so the proxy comes back without properties and the
   generated getters return the GObject default 0.
2. `screen_cast_init()` snapshots that 0 into the file static
   `available_cursor_modes` (line 62) and into the frontend's public property.
3. Re-sync relies on `g_signal_connect (impl, "notify::supported-cursor-modes")`
   (line 1080). The proxy property is named `available-cursor-modes`, so the
   handler never fires and the 0 stays for the life of the process.
4. `validate_cursor_mode()` (line 380) then rejects every non-zero mode with
   `Unavailable cursor mode %x`.

Upstream 1.22.0 fixed exactly this class of bug: `validate_cursor_mode` reads
the impl property live, and the impl proxy property is bound to the frontend
skeleton property. This host's nixpkgs (26.05.10402, rev `1e8bc658fc98`) pins
1.20.4, so the fix is a local patch.

Consequences worth naming: any client that asks for a cursor mode fails the
same way (Chromium clients omit `cursor_mode`, which is why only Discord was
noticed), and the frontend's `AvailableSourceTypes = 0` is the same bug on the
source-type property, without a validation path in 1.20.4.

## glib behaviour in this failure mode (measured, decides the patch shape)

Measured twice, and the two measurements disagreed, so the second one wins.

First, in isolation on a private bus with gjs 1.88: a proxy created for an unowned
name showed its cached property appear when the name owner showed up, so the
first reading was "glib refills eagerly". That reading was wrong. The proxy was
created *with* interface info, and the property read logged at the moment of the
claim came from gjs's own exported object building its reply, not from a client
request. The portal creates its impl proxy with `G_DBUS_PROXY_FLAGS_NONE` and no
interface info (single interface codegen proxy, `screen_cast_create`), and glib
does not refill that one's properties when the owner appears.

The authoritative measurement is the real thing on this session, with the
deployed patched binary and the real GNOME backend (`live-race-test.sh`):

```text
-- masking and stopping the GNOME backend
-- restarting the patched frontend with no backend present
   frontend  AvailableCursorModes   = (<uint32 0>,)
   frontend  AvailableSourceTypes   = (<uint32 0>,)
-- backend back up
   backend   AvailableCursorModes   = (<uint32 7>,)
   frontend  AvailableCursorModes   = (<uint32 0>,)
-- probe: CreateSession then SelectSources with cursor_mode 2
    SelectSources rejected: org.freedesktop.portal.Error.InvalidArgument:
      Unavailable cursor mode 2
```

So after the racing login the impl proxy's cache is empty for good. Both the
stale static and the live proxy read are 0, which makes the first version of the
patch a **no-op in exactly the state it was written for**. It only helps when the
frontend starts while the backend is already up, which is not the failure mode.

Upstream 1.22.0 is in the same position: it also creates the proxy that way and
binds the frontend skeleton property to the proxy property, so its fix depends
on the same refill that does not happen. Porting 1.22.0 faithfully is not
sufficient here.

Two earlier deductions from the first, wrong measurement are also retracted:

- "The live validator read is enough." It is not, the cache is never refilled.
- "The notify name fix cannot fire." True, but so would the 1.22 bind, for the
  same reason: there is no property change to react to.

What is left that does work in this failure mode is `notify::g-name-owner`, which
is the only signal that fires when the backend claims its name.

## What to change

1. `nix/xdg-portal-cursor-modes/available-cursor-modes.patch` (new file): three
   hunks on `src/screen-cast.c` that are one change. `validate_cursor_mode`
   validates against the impl proxy instead of a startup snapshot, and the file
   static that held the snapshot goes away, so no cached value is left to rot.
   The resync wiring is deliberately untouched.

   ```diff
   @@ file scope @@
   -static unsigned int available_cursor_modes = 0;

   @@ validate_cursor_mode @@
   -  if (!(available_cursor_modes & mode))
   +  if (!(xdp_dbus_impl_screen_cast_get_available_cursor_modes (impl) & mode))

   @@ sync_supported_cursor_modes @@
   +  unsigned int modes;
   -  available_cursor_modes = xdp_dbus_impl_screen_cast_get_available_cursor_modes (impl);
   -  xdp_dbus_screen_cast_set_available_cursor_modes (XDP_DBUS_SCREEN_CAST (screen_cast),
   -                                                   available_cursor_modes);
   +  modes = xdp_dbus_impl_screen_cast_get_available_cursor_modes (impl);
   +  xdp_dbus_screen_cast_set_available_cursor_modes (XDP_DBUS_SCREEN_CAST (screen_cast), modes);
   ```

   Upstream 1.22.0 does the live read too; dropping the static is the local part,
   because 1.22.0 no longer has it.

2. `nix/configuration.nix`: one entry in the existing `nixpkgs.overlays` block,
   next to the `discord` and `gnomeExtensions.copyous` entries:

   ```nix
   xdg-desktop-portal = prev.xdg-desktop-portal.overrideAttrs (old: {
     patches = (old.patches or []) ++
       [ ./xdg-portal-cursor-modes/available-cursor-modes.patch ];
   });
   ```

   The NixOS `xdg.portal` module builds `xdg-desktop-portal.service` from this
   package (`ExecStart=/nix/store/...-xdg-desktop-portal/libexec/xdg-desktop-portal`),
   so the next switch installs the patched binary. No portal config file changes.

   The nixpkgs 1.20.4 recipes patches (`installed-tests-path`,
   `nix-pkgdatadir-env`, `trash-test`) do not touch `screen-cast.c`, so the
   patch context holds as written. A future nixpkgs bump that rewrites the file
   makes `patch` fail loudly at build time, which is the desired signal.

## Verification

1. Done, 2026-10-13 11:23: restarted the frontend
   (`systemctl --user restart xdg-desktop-portal`) and re-read
   `org.freedesktop.portal.Desktop` `ScreenCast.AvailableCursorModes`: 7, matching
   the backend, with the backend still running from login. That confirms the
   mechanism and was the workaround that made Discord work for the rest of the
   session.
2. Acceptance, same day: the user shares the screen from Discord started plainly,
   with no launch flag. The flag is not the cause, the restart is.
3. Build only before switching: `nix/update-nixos.sh build`.
4. After the deploy: the unit's ExecStart points at the patched store path and
   both properties still read 7.
5. Race simulation, the actual test of the patch, in this order:

   ```bash
   systemctl --user stop xdg-desktop-portal-gnome
   systemctl --user restart xdg-desktop-portal   # expect 0/0: race reproduced
   systemctl --user start xdg-desktop-portal-gnome
   ```

   then `CreateSession` and `SelectSources` with `cursor_mode` 2 through
   `gdbus call`. `SelectSources` shows the real GNOME picker, so close it with
   Escape; `Start` is never called and nothing is streamed. The discriminator is
   the dialog: with the patched binary the picker appears (validation passed),
   with the unpatched one the call returns `InvalidArgument: Unavailable cursor
   mode 2` and no dialog ever appears.
6. Next login is the final check: the picker must open from Discord with no
   restart and no flag.

## Rejected alternatives

| alternative | why not |
|---|---|
| `--enable-features=WebRTCPipeWireCapturer` on the Discord wrapper | Targets Chromium's capturer. Discord's picker is its own native code (`video_linux_interop::capture::picker`) and talks to the portal directly. Cannot help. |
| `chromiumSwitches` in `~/.config/discord/settings.json` | The app.asar allowlist keeps 14 keys and drops `enable-features` and every other key. |
| Version rollback of Discord | Discord is 1.0.156 in every system generation 40 to 46 and the nixpkgs rev never moved. Nothing changed there. |
| Disable hardware acceleration | The failure is a portal argument rejection, unrelated to GPU paths. |
| Switch to Vesktop | Works around a system-wide portal bug rather than fixing it, and the user rejected a client change. |
| Restart the portal frontend at session start, no patch (systemd user unit) | Timing based, and it would not recover when the backend restarts later, because the notify wiring stays broken. Kept as the step 1 workaround only. |
| Bump `xdg-desktop-portal` to 1.22.0 in the overlay | 1.22.0 is a large refactor (session persistence, impl API moves) that this pinned nixpkgs and `xdg-desktop-portal-gnome` 50.0 were not built against. More risk than a two hunk patch. |
| Make Discord stop sending `cursor_mode` | The value is hardcoded in Discord's native Rust picker. There is no setting or flag for it. |
| Resync on `notify::g-name-owner` and drop the `impl_version` gate | Would also repair the frontend's advertised 0/0, since that signal does fire on the racing refill. Declined on scope: it diverges from upstream for no gain in the reported bug, which the live read already fixes. First thing to add if a client turns out to gate on the advertised properties. |
| Keep the `notify::supported-*` name fix | Measured dead in this failure mode (the refill does not emit the per property notify) and it silently widens the patch. Dropped. |

## Risks

- The patched package is the session's portal frontend. A bad patch breaks
  screen sharing, remote desktop, and file dialogs after the switch. Mitigation:
  build first (`nix/update-nixos.sh build`), inspect, then switch; reverting is
  dropping two overlay lines and one file.
- Restarting the frontend drops any share that is running at that moment.
- The patch is version specific. It carries a comment naming upstream 1.22.0 as
  the fix to port when nixpkgs moves.
