# C++ headers for clangd, portable across distros

## Problem

nvim's clangd reports `'bits/stdc++.h' file not found` on C++ buffers. The
dotfiles are also used on non-NixOS systems, so nothing in them may point at a
`/nix/store` path or at `/run/current-system`.

## Can the .nix file fix clangd?

No, and this is measured, not assumed:

- clangd builds its own compiler arguments and searches a fixed list: its
  resource dir, `/usr/local/include`, `/usr/include`. Setting
  `CPLUS_INCLUDE_PATH` or `CPATH` changes nothing (both tested, still
  `file not found`).
- The only nix-level way to satisfy that fixed list is to mirror gcc's C++
  headers into `/usr/local/include`, and glibc's headers too (they are needed as
  soon as `<bits/stdc++.h>` pulls in `<cstdlib>`). That duplicates the FHS layout
  inside NixOS and fights the model. Rejected.
- What nix can and should do is keep a `g++` on `PATH`. `stdenv.cc` already does
  (`/run/current-system/sw/bin/g++`), so no package is missing.

## The portable fix (dotfiles only)

clangd can be told which compiler to query for system include paths, and the
compiler may be a bare name resolved through `PATH`:

- `common/.config/clangd/config.yaml` (new): `CompileFlags.Compiler: g++`.
- nvim passes the allow list clangd requires:
  `--query-driver=/usr/bin/g++,/usr/local/bin/g++,/opt/homebrew/bin/g++,/run/current-system/sw/bin/g++`.

Tested with the real Mason clangd 23.1.0 on this host: `clangd --check` on a
`bits/stdc++.h` file reports 0 errors and logs
`System includes extractor: successfully executed /run/current-system/sw/bin/g++`.

Why this is portable: the config file names no absolute path, the flag list
covers Debian, Arch, both Homebrew prefixes and NixOS, and on a distro where the
compiler sits elsewhere clangd falls back to today's behaviour instead of
erroring. On macOS `/usr/bin/g++` is Apple clang and reports the SDK includes.

## Decisions

1. Chosen: driver query through a bare `g++`. Rejected: absolute
   `/run/current-system/sw/bin/g++` (breaks the other distros, this was the
   first draft); hardcoded `-isystem /nix/store/...` (store hash changes every
   rebuild); per-project `.clangd` files (repeated in every project); swapping in
   nixpkgs `clang-tools` (still knows nothing about the gcc toolchain).
2. Chosen: keep `stdenv.cc` and say why in its comment, so a later cleanup does
   not remove the compiler clangd queries. No new package, no header package.
3. The `libstdc++.so.6` runtime failure of `sharp` moves to plan 46. No
   system-wide mechanism reaches a nix `bun` or `node` process (nix-ld only
   feeds foreign executables, the loader has no `/lib` or `/usr/lib` system path
   and the generation ships no `/etc/ld.so.cache`), but once mise supplies those
   runtimes they are foreign binaries, and `programs.nix-ld.libraries` with
   `stdenv.cc.cc.lib` reaches them.

## Changes

- `common/.config/clangd/config.yaml` (new): `CompileFlags.Compiler: g++` plus a
  comment naming the nvim flag it depends on.
- `common/.config/nvim/lua/plugins/lsp.lua`: override clangd's command with the
  `--query-driver` list. lspconfig's default is a bare `{ 'clangd' }`, so nothing
  else is lost.
- `nix/configuration.nix`: extend the `stdenv.cc` comment to record that its
  `g++` is what clangd queries. Comment only, no behaviour change.

## Risks

- Where a project ships `compile_commands.json`, `Compiler` overrides the
  database's compiler. The only compiler on the NixOS host is the profile gcc,
  so that is the wanted behaviour.
- On a machine with no `g++` at all, clangd keeps today's behaviour (missing C++
  headers) instead of failing to start.

## Verification

- `clangd --check` on a `bits/stdc++.h` file with the new config and flag list:
  0 errors.
- `link-files.bash --fix` links the new dotfile, then `--audit` stays clean.
- `bats tests/link-files.bats`: 99 ok.
- In nvim, open a C++ file and confirm no diagnostic on the include.

## Out of scope, other repo

Instatic needs nothing once plan 46 lands: `sharp`'s `libstdc++.so.6` resolves
through nix-ld inside mise's bun. Until then, run it as:

```bash
LD_LIBRARY_PATH=$(nix eval --raw nixpkgs#stdenv.cc.cc.lib)/lib bun test
```
