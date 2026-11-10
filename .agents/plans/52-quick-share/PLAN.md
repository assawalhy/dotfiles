# Plan: Quick Share file transfer

## Goal

Share files with the Android phone over the local network with Google Quick Share:
no cloud, no account, and the receiver on this box is running whenever the desktop is.

Scope agreed with the user: both directions, phone → PC first.

## What is actually available

Google ships no Quick Share client for Linux. The only implementation is
[Martichou/rquickshare](https://github.com/Martichou/rquickshare) (GPL-3.0, ~3.6k
stars), a Tauri + WebKitGTK app that speaks the Nearby Share/Quick Share protocol
over Wi-Fi, advertising itself with its own mDNS responder and an optional BLE hint.

nixpkgs (26.05) already packages it at 0.11.5, which is also upstream's newest
release (2025-02-23). So the package needs no work of its own.

Verified on this box (2026-11-10) by running the nixpkgs binary for 10 s against a
throwaway `$HOME`:

```
INFO rqs_lib: TcpListener on: 0.0.0.0:34933
INFO rqs_lib::hdl::mdns: Broadcasting with: nixos
INFO rqs_lib::hdl::ble: BleListener: service starting
INFO rqs_lib::hdl::mdns: MDnsServer: service starting
```

No missing libraries, no blank WebKit window on the hybrid GPU, only two cosmetic
`gtk_widget_get_scale_factor` warnings. The run also showed the shape of the app's
own state: `~/.local/share/dev.mandre.rquickshare/.settings.json`
(`autostart`, `startminimized`, `visibility`, `realclose`) and
`~/.config/autostart/RQuickShare.desktop`, created on first start with the store
path as `Exec`.

System facts that shape the plan:

- `bluetooth.service` is active and `hci0` is unblocked; no `hardware.bluetooth`
  entry exists in `nix/`, and none is needed, the BLE listener starts fine as is.
- The firewall is on (`firewall.service` active, only `checkReversePath = false`
  set), so the inbound TCP port and mDNS multicast need explicit holes.
- Brave holds `224.0.0.251:5353` on three sockets. A second UDP bind of `0.0.0.0:5353`
  with `SO_REUSEADDR|SO_REUSEPORT` succeeds, so discovery and Brave coexist. No Avahi.

## What changes

| File | Change |
|---|---|
| `nix/configuration.nix` | `rquickshare` in the GNOME `[gui]` packages; `networking.firewall.allowedTCPPorts = [ 12345 ]` and `allowedUDPPorts = [ 5353 ]` |
| user state, not the repo | `~/.local/share/dev.mandre.rquickshare/.settings.json` seeded once with `"port": 12345`, `"startminimized": true` |
| `.agents/plans/52-quick-share/` | this plan and its TODO |

## Decisions

### D1 Package: nixpkgs `rquickshare`, no wrapper

`environment.systemPackages` gets the plain package next to the other `[gui]` apps.
The store build is the release upstream says to use, it starts on this GPU without a
WebKit workaround, and `rquickshare` has no updater of its own, so a system package
tracks it exactly as well as a user-space copy would.

Rejected:

- `pkgs.localsend` (1.18.0): needs LocalSend installed on the phone. Different
  product, and the phone already has Quick Share built in.
- `gnomeExtensions.gsconnect` / KDE Connect: pairing, a phone app, and a different
  transfer path.
- Flatpak: no Flathub listing, so it would be a hand-rolled manifest or a bundled
  AppImage.
- Google's Windows app under Wine: the Windows client itself is being retired and
  the layer adds nothing.

### D2 Pinned port 12345 plus two firewall holes

`core_lib` binds `0.0.0.0:${port}` with `port` read from the app's store, defaulting
to `0`, a random ephemeral port. A random port cannot be written into
`networking.firewall.allowedTCPPorts`, so the store gets a fixed `"port": 12345`
(free on this box) and the firewall opens that one port plus `5353/udp` for the
inbound mDNS answers the phone sends as multicast. Without 5353 the app advertises
fine but never hears the phone.

The store file is user state, so the plan seeds it once with `jq` instead of
declaring it: `systemd.user.tmpfiles` with `C` would rewrite the file at every boot
and silently undo any settings the user changes in the app.

Rejected:

- Opening a TCP port range: it would have to cover the whole ephemeral range.
- Leaving the firewall closed and relying on outbound connections: receiving is an
  inbound connection from the phone, so it would never arrive.
- `services.avahi.enable`: the app ships and drives its own mDNS responder; a second
  responder on 5353 only fights it.

### D3 Always-on receiver, reopened from the app grid, no tray

Keep the app's own autostart entry (`autostart: true` is its default) and add
`startminimized: true`, so a login starts the receiver with no window. Closing the
window does not quit (the app hides instead unless `realclose` is set), and a second
launch hits `tauri_plugin_single_instance`, which brings the running window back.
That covers the whole lifetime without a tray icon.

Rejected:

- `gnomeExtensions.appindicator` (in nixpkgs, supports shell 50): a permanent
  indicator slot plus a system extension for one app that the app grid already
  reopens.
- `realclose: true` and no autostart: nothing would be listening when the phone looks
  for the PC, which is the entire point of the receiver.
- A systemd user unit instead of the app's autostart: it would need the graphical
  session environment, and the app already writes a working entry.

### D4 No Bluetooth work

`bluetooth.service` runs, `hci0` is unblocked, and the BLE listener started in the
smoke test. Nothing to add to `nix/`, and no rfkill or power-on step is needed.

### D5 No WebKit compositing workaround by default

The box is hybrid Intel/NVIDIA, which is where WebKitGTK renders blank with
compositing on. The smoke test did not hit it, so `WEBKIT_DISABLE_COMPOSITING_MODE=1`
stays documented here as the fallback rather than being wrapped in preemptively:
it costs smooth scrolling and is not needed until a window actually comes up blank.
If it is needed, the fix is a `nix/rquickshare.nix` wrapper with `makeWrapper`, not a
system-wide environment variable.

## Risks

- Upstream is quiet: last release 2025-02-23, last `master` commit 2025-06-16, while
  Android's Quick Share keeps moving. A protocol change would end this package until
  someone fixes it upstream.
- Open issue #431 (2026-06-18): some phones advertise a 17-byte `n=` mDNS TXT entry,
  and `rqs_lib` rejects anything under 19 bytes with `Invalid data length`, dropping
  the phone from the PC's device list. Receiving from the phone is unaffected; sending
  PC → phone is. Two open PRs (#433, #439) fix the parser. The plan patches only if
  the PC → phone test actually shows the phone missing. Verified on 2026-11-10: this
  phone's device entry parses fine and receives files, so the patch stays off.
- The autostart `.desktop` the app writes points at a Nix store path. After a nixpkgs
  bump the old path can be garbage-collected, leaving a dead autostart entry until the
  app is launched once by hand.
- The firewall hole is one port. Change the pinned port in the app and receiving stops
  silently until the firewall rule follows.

## Verification

1. `nix/update-nixos.sh` switches clean, then `ss -ltnp | grep 12345` shows the app.
2. Launch from the app grid: a window opens on the Quick Share UI, not a blank page.
3. Phone → PC: share a photo from the phone, it appears on the PC, accept, and the
   file lands in `~/Downloads`.
4. PC → phone: the phone shows up in the device list and receives a file. This is
   where #431 would surface.
5. Close the window and launch again from the grid: the same process shows its window
   again (`pgrep -c rquickshare` stays 1).
6. At the next login: no window, and `ss -ltn | grep 12345` still listening.
