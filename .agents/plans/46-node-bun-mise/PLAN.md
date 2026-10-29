# node and bun from mise, latest, floating

## Ask

Use mise for node and bun instead of the nix-pinned versions, with `latest` and
no explicit pinning.

## What I verified

- nix 26.05 ships node v24.21.0 (npm 11.19.0) and bun 1.3.13. mise resolved node
  26.12.1 and bun 1.4.4, and both are now installed.
- mise 2026.5.12 defaults `node.compile` to true and then builds node from
  source, which died on `make: command not found`. With `node.compile = false` it
  downloads the upstream prebuilt binary. The setting lives in the repo config
  and `mise settings get node.compile` reads it from there.
- mise's node and bun are foreign ELF binaries (`/lib64/ld-linux-x86-64.so.2`),
  so they run through the nix-ld stub. With only
  `/run/current-system/sw/share/nix-ld/lib` on the library path, `ldd` resolves
  node's `libstdc++.so.6` and `libgcc_s.so.1` from there. bun needs neither.
- nixpkgs' `nixos/modules/programs/nix-ld.nix` already seeds
  `programs.nix-ld.libraries` with the gcc libraries ("all libraries from
  systemd and nix"), so libstdc++ was present before any edit. An earlier draft
  added `stdenv.cc.cc.lib`; it evaluated to a duplicate gcc-15.3.0 and was
  removed.
- `mise activate` lives in `common/.bash_profile`, so only interactive shells get
  mise's PATH. `config/java.lua` already works around that for the JDK.
- mise warned `gpg not found, skipping verification` on the bun download, so the
  only integrity check on those downloads was disabled. `gnupg` was not in the
  system packages.
- `setup/packages.list` installs `mise` on every distro and `bun` natively.

## Decisions

1. **mise owns node and bun**, both `latest`, declared in the repo-managed
   `common/.config/mise/config.toml` next to java and kotlin. Floating on
   purpose: `latest` re-resolves only on install or `mise upgrade`, so a bad
   upstream release lands on an explicit command, not on shell start.
2. **`node.compile = false` is recorded in the same file.** Without it a fresh
   machine tries to build node from source and needs make, a full gcc toolchain
   and a long build.
3. **Keep `nodejs` in nix.** It is the fallback for GUI-launched consumers:
   Mason's `ts_ls`, `eslint`, `pyright`, `intelephense` and `prismals` run through
   `#!/usr/bin/env node`, and nvim from GNOME never runs `mise activate`. Chosen
   over teaching every server a `cmd_env` with a versioned mise path, which
   breaks again on every node upgrade.
4. **Drop `bun` from nix and from `setup/packages.list`.** No GUI consumer needs
   it, and one owner per tool across distros is the point of mise.
5. **Add `gnupg`**, so mise actually verifies the signatures of the runtimes it
   downloads instead of warning and skipping.
6. **No `programs.nix-ld.libraries` change.** libstdc++ was already there; the
   original `sharp` failure was a nix-built bun, which never passes through the
   stub. Moving the runtime to mise is the whole fix.

## Changes

- `common/.config/mise/config.toml`: `node = "latest"`, `bun = "latest"`, and
  `[settings.node] compile = false`.
- `nix/configuration.nix`: remove `bun`; extend the `nodejs` comment; add
  `gnupg`; note in the nix-ld block why no gcc entry is needed.
- `setup/packages.list`: remove the `bun` line.

## Risks

- Two node versions on a NixOS host: mise's in interactive shells, nix's in GUI
  and non-interactive contexts. The fixed one only serves LSP servers and
  shebang scripts, never a project build.
- `latest` has no lockfile. A broken release is fixed with
  `mise use -g node@<version>` or by falling back to the nix one.
- A fresh machine needs `mise install` after `setup-os`, because bun no longer
  comes from the package manager.
- `npm install -g` through mise's node writes into mise's prefix, while setup-os
  forces `~/.local`. Both stay on PATH; ownership of npm globals is mixed.
- `node.compile = false` assumes an upstream prebuilt exists for the platform.
  Where none exists the install fails instead of building.

## Verification

Done here:

- `mise install`: node v26.12.1, bun 1.4.4, npm 11.20.0.
- `readelf` shows `/lib64/ld-linux-x86-64.so.2` for both, and `ldd` resolves
  node's libstdc++ from the nix-ld path.
- Module evaluation of the edited config with a stub hardware file: `bun` absent,
  `nodejs` and `gnupg` present, one gcc entry in `programs.nix-ld.libraries`.
- `sharp` loads under mise's bun in Instatic (vips 8.18.3). Caveat: this session's
  `/usr` is bind-mounted from an appimage-run rootfs that already carries
  libstdc++, so this run does not prove the host case on its own.

Left for the host:

- `nix/update-nixos.sh build`, then switch. Not runnable here: sudo is blocked by
  the no-new-privileges flag and `/etc/nixos` is not visible.
- In Instatic, from a shell where `findmnt /usr` prints nothing:
  `bun -e 'require("sharp")'`.
- Launch nvim from GNOME and check `:lua print(vim.fn.exepath('node'))` resolves
  to the nix `nodejs`.
