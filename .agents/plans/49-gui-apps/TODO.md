# TODO: self-updating GUI apps

- [x] 1. `nix/configuration.nix`: `environment.etc."herdr-app/nix-ld-extra"` with the wayland and vulkan-loader lib dirs, comment naming D1.
- [x] 2. `setup/steps/63-herdr.sh`: install herdr-app when the binary is missing, write the `~/.local/bin/herdr-app` wrapper, extend `# check:`.
- [x] 3. `nix/configuration.nix`: `services.flatpak.enable` and the `flatpak-update` user service with its daily timer.
- [x] 4. `setup/steps/64-slack.sh`: flathub remote and the user install of `com.slack.Slack`, `# requires: flatpak`.
- [x] 5. `common/.local/share/applications/t3-chat.desktop` and `common/.local/share/icons/hicolor/192x192/apps/t3-chat.png`, linked into `~/.local/share`.
- [x] 6. Rebuild with `nix/update-nixos.sh`, then run steps 63 and 64.
- [ ] 7. Verify per PLAN.md: herdr window (starts through the wrapper, no Wayland panic; the in-app update download hit a `Connection reset by peer` and retries), update flow, opencode paste, Slack (4.53.280 launches), T3 Chat.
- [x] 8. Commit `nix/`, `setup/`, `common/` and the plan.

Checks so far: `nix-instantiate --parse nix/configuration.nix` clean, `nixos-rebuild dry-build` exit 0, `bash -n` clean on both steps, icon cache refreshed for the new entry.
