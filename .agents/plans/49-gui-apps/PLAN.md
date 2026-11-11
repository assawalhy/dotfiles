# Plan: self-updating GUI apps

## Goal

Slack installed, T3 Chat reachable as an app, and Herdr launching on this Wayland desktop.
All three keep the app binary in user space so updates never need `nixos-rebuild`, the split epic 21 established.

## Symptom (verified 2026-10-30)

```
$ ~/.local/bin/herdr-app
thread 'main' panicked at vendor/gpui-pre-linux/src/linux/platform.rs:365:45:
failed to connect to Wayland compositor: The wayland library could not be loaded
```

herdr-app is a GPUI binary that dlopens `libwayland-client.so.0` and `libvulkan.so.1`, and `ldd` lists neither.

nix-ld's directory `/run/current-system/sw/share/nix-ld/lib` has `libxcb`, `libxkbcommon` and `libgbm`, and deliberately no `libwayland-client` (epic 04 D5: exposing it moves opencode/OpenTUI to a Wayland clipboard backend GNOME cannot serve). It has no Vulkan loader either.

Supplying both at launch fixes it: with `NIX_LD_LIBRARY_PATH=$NIX_LD_LIBRARY_PATH:<wayland>/lib:<vulkan-loader>/lib` the window opens and the process stays up (8 s timeout, no panic).
Wayland alone is not enough: without the loader it fails one step later with `Failed to create surface for any enabled backend: {}`.

## What changes

| File | Change |
|---|---|
| `nix/configuration.nix` | `environment.etc."herdr-app/nix-ld-extra"`, `services.flatpak.enable`, and a daily `flatpak update` user timer |
| `setup/steps/63-herdr.sh` | install herdr-app when absent, write the `~/.local/bin/herdr-app` wrapper, extend `# check:` |
| `setup/steps/64-slack.sh` | new: flathub remote and `flatpak install --user com.slack.Slack` |
| `common/.local/share/applications/t3-chat.desktop` | new: Brave app window |
| `common/.local/share/icons/hicolor/256x256/apps/t3-chat.png` | new: icon for that entry |

## Decisions

### D1 herdr-app: user-space wrapper, library paths from Nix

`~/.local/bin/herdr-app`, the path herdr's installer creates as a symlink to `~/.local/share/herdr-app/herdr-app`, becomes a wrapper:

```sh
#!/usr/bin/env bash
set -euo pipefail
extra=$(cat /etc/herdr-app/nix-ld-extra)
export NIX_LD_LIBRARY_PATH="${NIX_LD_LIBRARY_PATH:-/run/current-system/sw/share/nix-ld/lib}$extra"
exec "$HOME/.local/share/herdr-app/herdr-app" "$@"
```

Nix writes the one line it reads:

```nix
environment.etc."herdr-app/nix-ld-extra".text =
  ":${pkgs.wayland}/lib:${pkgs.vulkan-loader}/lib";
```

Why this shape:

- The binary stays at `~/.local/share/herdr-app/herdr-app`. The in-app updater (`src/update.rs`) downloads `app.tar.gz`, swaps that file and execs it, and never touches `~/.local/bin` or the `.desktop`. The wrapper and the existing desktop entry therefore survive updates unchanged.
- The store paths live in `/etc` and are regenerated on every rebuild, so user space never holds a path the GC can remove.
- `NIX_LD_LIBRARY_PATH` is what nix-ld's `ld.so` reads, and it does not leak into the terminals herdr spawns.

Rejected:

- `programs.nix-ld.libraries += wayland`: one line, fixes every future GUI binary, and regresses opencode image paste (epic 04 D5).
- Per-app `LD_LIBRARY_PATH`: works, leaks into every spawned terminal, and the wrapper needs the variable to be inherited by the exec'd child anyway.
- `buildFHSEnv` wrapper: a full FHS closure to obtain two libraries.
- `nixpkgs.herdr`: the app must update itself, a store copy cannot.

Drift: re-running `releases.herdr.dev/app/install.sh` recreates `~/.local/bin/herdr-app` as a symlink. Re-run step 63 to restore the wrapper.

### D2 Slack: Flathub, user install, timer updates

- `services.flatpak.enable = true` needs one rebuild. `xdg.portal` is already enabled; the portal D-Bus services are present.
- Install `com.slack.Slack` from Flathub with `--user`. Flathub serves Slack 4.52.182, the same version as the current `.deb`, on `org.freedesktop.Platform` 25.08.
- Updates come from `systemd.user.services.flatpak-update` (`flatpak update --user --noninteractive -y`, oneshot) on a daily `Persistent` timer, declared in Nix so it survives rebuilds. Flatpak ships only `flatpak-system-helper.service`, no updater of its own.
- Screen sharing works through the PipeWire portal on Wayland, which the `.deb` does not do.

Rejected:

- `pkgs.slack`: store copy, updates only on rebuild.
- Slack `.deb` extracted into `~/.local/opt`: Slack's Linux updater is an apt repo plus `/etc/cron.daily/slack`, so a user-space copy never updates.
- WebCatalog and similar wrappers: third party.

Cost: about 1.5 GB for the app and the freedesktop runtime. Flatpak apps do not share the Nix store, so their GTK and Electron libraries are duplicated.

### D3 T3 Chat: Brave app window from a committed desktop entry

There is no official desktop app. `feedback.t3.chat/p/desktop-app-19` is still "Gathering Interest" as of October 2026, and the web app is the product.

`common/.local/share/applications/t3-chat.desktop` follows the existing `open-pencil.desktop` and `orca-ide.desktop`:

```ini
Exec=brave --app=https://t3.chat --class=T3Chat
StartupWMClass=T3Chat
Icon=t3-chat
```

The site is the app, so it is always current.

Rejected:

- WebCatalog: paid third-party wrapper.
- `0xGingi/T3_Chat_Electron`: unofficial and unmaintained Electron shell.
- Brave PWA install: better identity (own app id and profile), but it writes `~/.local/share/applications/brave-*-Default.desktop` as user state outside the repo. Keep it as the fallback if `--class` grouping fails.

## Risks

- `--class` may be ignored for `--app` windows, in which case GNOME groups the window under Brave's icon. The fallback is the PWA install D3 rejects.
- Enabling Flatpak adds polkit, fuse3 and a font directory to the system closure. The first rebuild compiles more than one package.
- A future herdr release could dlopen another library. The wrapper is the single place to extend.

## Verification

1. `herdr-app` from the app grid opens a window and `ps` shows the process.
2. In-app Check for updates still downloads, swaps and relaunches.
3. opencode image paste still works, so epic 04's regression stayed fixed.
4. Slack launches from the grid and signs in, `flatpak update` is a no-op, and `systemctl --user list-timers flatpak-update` lists the schedule.
5. T3 Chat opens in its own window and GNOME groups it under the T3 Chat icon.
