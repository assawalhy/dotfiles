# TODO: portable C++ headers for clangd

- [x] Add `common/.config/clangd/config.yaml` with `CompileFlags.Compiler: g++`
- [x] Override clangd's command in `common/.config/nvim/lua/plugins/lsp.lua` with
      the cross-distro `--query-driver` list
- [x] Extend the `stdenv.cc` comment in `nix/configuration.nix`
- [x] `clangd --check` on a `bits/stdc++.h` file: 0 errors
- [x] Link the new dotfile with `link-files.bash --fix`, then `--audit` clean
      (no finding touches a changed file; the 35 `[unlinked]` entries are
      pre-existing pi session and desktop-file capture candidates)
- [x] `bats tests/link-files.bats`: 99 ok
- [x] Instatic needs nothing once plan 46 lands; the plan records the interim
      command (no repo change there)
