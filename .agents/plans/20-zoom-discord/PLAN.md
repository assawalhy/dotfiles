# PLAN — add Zoom + Discord to NixOS

## Goal

Install **Zoom (zoom-us)** and **Discord** on the NixOS machine and activate them
in the current system generation (`environment.systemPackages`), then commit.

## Approach

One new block in `configuration.nix` (Zoom) + one line in the `[gui]` section
(Discord), deploy `/etc/nixos/configuration.nix` with a timestamped backup, then
`nixos-rebuild switch` through the zenity askpass helper.

```
configuration.nix
├── programs.zoom-us.enable = true      # NEW — module, not a raw package
└── environment.systemPackages
    └── [gui] … discord                 # NEW — one line, next to typora/obsidian
```

### Decisions

- **D1 `programs.zoom-us.enable = true`, not `zoom-us` in systemPackages.**
  The NixOS module (`nixos/modules/programs/zoom-us.nix`) auto-derives
  `pulseaudioSupport` (pipewire+pulse is on here) and
  `gnomeXdgDesktopPortalSupport` (GNOME is on) and feeds
  `xdg-desktop-portal-gnome`/`-gtk` into the FHS closure. Zoom's screen share on
  Wayland needs that portal; a bare `pkgs.zoom-us` gets neither.
- **D2 `discord` as a plain package, no module.** There is no
  `programs.discord` in this nixpkgs (`f.options.programs ? discord` →
  `false`); `pkgs.discord` already wraps GTK3/pulse/wayland itself.
- **D3 both are unfree** — already covered by the existing
  `nixpkgs.config.allowUnfree = true`, no new acceptance needed.
- **D4 not in the binary cache.** Verified with
  `nix-build '<nixpkgs>' -A discord -A zoom-us --dry-run`: 26 derivations build
  locally (Discord's tarball + `autoPatchelf`, Zoom's `buildFHSEnv`
  rootfs/profile/bwrap). Downloads ≈ Zoom 190 MB + Discord 100 MB, builds are
  mostly copies. No pinning/overlays.
- **D5 rejected: flatpak** (`us.zoom.Zoom`). Adds `flatpak`, the daemon and
  portal plumbing for a sandbox we don't need — Zoom's nixpkgs package already
  ships a working FHS wrapper.
- **D6 rejected: pinned-old Zoom version.** nixpkgs 6.3.x had the SSO-hang /
  RAM-leak bugs; the 26.05 channel's 7.1.5.4332 is the FHS-era build that
  works, so take what the channel ships.

## Milestones

1. Edit `configuration.nix` (Zoom module + Discord line).
2. Parse check (`nix-instantiate --parse`).
3. Backup + copy to `/etc/nixos`, `nixos-rebuild switch` (zenity askpass).
4. Verify: `zoom --version`, `discord --version` present in
   `/run/current-system/sw/bin`, desktop entries in the GNOME app grid.
5. Commit.

## Risks

- Rebuild needs sudo → pops the zenity password dialog; it blocks until you type
  it. Long build phase (both packages compile/download from upstream).
- Zoom is an FHS (`bwrap`) app — known to need `~/.config/zoomus.conf` tweaks on
  some setups; screen share may still need `xwayland = true` inside Zoom.
- Deploying also syncs the one pre-existing drift line (`imagemagick` comment)
  that was already only in the repo copy.
