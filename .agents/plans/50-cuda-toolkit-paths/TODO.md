- [x] 1. configuration.nix: cudatoolkit in systemPackages, /usr/local/cuda tmpfiles layout, NVCC_PREPEND_FLAGS
- [x] 2. dotfiles: add `common/bin/gxx-cuda` wrapper and link it into `~/bin`
- [x] 3. dotfiles: clangd `Compiler: gxx-cuda`, lsp.lua `--query-driver` entry
- [x] 4. `sudo nixos-rebuild switch`
- [x] 5. Verify: plain `make` in all five dirs, `make sm=75` run ger/gemm, clangd --check 0 errors

Done. Plain `make` now compiles all five directories, `make sm=75` runs ger and
gemm to TEST PASS, and `clangd --check` reports 0 errors on the five `.cu` files
and on a `bits/stdc++.h` file with no extra flags.

One thing clangd needed beyond the symlink: it finds the CUDA SDK by taking the
`nvcc` in PATH, and `/run/current-system/sw/bin/nvcc` resolves into the
`cuda_nvcc` derivation, which ships no `cuda_runtime.h`. So the clangd config
also passes `--cuda-path=/usr/local/cuda`, scoped to `.cu`/`.cuh` because the
flag is an unused argument for plain C++.

Existing terminals keep the pre-switch environment: `__NIXOS_SET_ENVIRONMENT_DONE`
is exported, so child shells skip `/etc/set-environment` and never see
`NVCC_PREPEND_FLAGS`. Open a new terminal, or
`unset __NIXOS_SET_ENVIRONMENT_DONE && . /etc/set-environment`.
