- [x] 1. configuration.nix: cudatoolkit in systemPackages, /usr/local/cuda tmpfiles layout, NVCC_PREPEND_FLAGS
- [x] 2. dotfiles: add `common/bin/gxx-cuda` wrapper and link it into `~/bin`
- [x] 3. dotfiles: clangd `Compiler: gxx-cuda`, lsp.lua `--query-driver` entry
- [ ] 4. `sudo nixos-rebuild switch` (needs the user's password)
- [ ] 5. Verify: plain `make` in all five dirs, `make sm=75` run ger/gemm, clangd --check 0 errors

Pre-switch checks done: `nixos-rebuild build` succeeds, the built system carries
NVCC_PREPEND_FLAGS and the /usr/local/cuda tmpfiles rules, and clangd --check is
0 errors on ger.cu, gemm.cu and a `bits/stdc++.h` file once a CUDA root is passed.
