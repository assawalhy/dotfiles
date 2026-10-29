# TODO: node and bun from mise

- [x] Add `node = "latest"` and `bun = "latest"` to
      `common/.config/mise/config.toml`
- [x] Set `node.compile = false`: mise 2026.5.12 defaults it to true and tried to
      build node from source, which died on `make: command not found`
- [x] `mise install`: node 26.12.1, bun 1.4.4, npm 11.20.0
- [x] Confirm both are foreign ELF (`readelf -l` shows
      `/lib64/ld-linux-x86-64.so.2`) and that node's libstdc++ resolves from
      `/run/current-system/sw/share/nix-ld/lib`
- [x] Remove `bun` from `nix/configuration.nix` and from `setup/packages.list`
- [x] Extend the `nodejs` comment in `nix/configuration.nix` (GUI and LSP
      fallback, not the project runtime)
- [x] Add `gnupg`: mise warned `gpg not found, skipping verification` on the bun
      download, so the only integrity gate on those downloads was disabled
- [x] No `programs.nix-ld.libraries` change after all: nixpkgs' nix-ld module
      already seeds the list with the gcc libraries. The draft
      `stdenv.cc.cc.lib` entry evaluated to a duplicate gcc-15.3.0 and was
      removed; a note in the block records why it stays out
- [x] Module evaluation with a stub hardware file: `bun` absent, `nodejs` and
      `gnupg` present, one gcc entry in the nix-ld list
- [ ] `nix/update-nixos.sh build`, then switch. Not runnable from this session:
      sudo is blocked by the "no new privileges" flag and `/etc/nixos` is not
      visible inside the appimage-run namespace
- [ ] In Instatic, `bun -e 'require("sharp")'` from a shell outside the
      appimage-run namespace (`findmnt /usr` empty). This session sits inside
      one whose `/usr` already carries libstdc++, so it cannot prove the fix
- [ ] Confirm a GUI-launched nvim still resolves `node`
