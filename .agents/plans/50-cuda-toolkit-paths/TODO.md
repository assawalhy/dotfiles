- [x] 1. configuration.nix: cudatoolkit in systemPackages, /usr/local/cuda tmpfiles layout, NVCC_PREPEND_FLAGS
- [x] 2. dotfiles: add `common/bin/gxx-cuda` wrapper and link it into `~/bin`
- [x] 3. dotfiles: clangd `Compiler: gxx-cuda`, lsp.lua `--query-driver` entry
- [x] 4. `sudo nixos-rebuild switch`
- [x] 5. Verify: plain `make` in all five dirs, run ger/gemm, clangd --check 0 errors

## Phase 2: the binaries would not run

- [x] 6. configuration.nix: prepend `-Xlinker -rpath -Xlinker /run/opengl-driver/lib`
      so static cudart can dlopen the driver
- [x] 7. clangd config: `--cuda-path=/usr/local/cuda`, scoped to `.cu`/`.cuh`
- [x] 8. makefiles: default `sm=80` -> `sm=75` in all five, and drop the stale
      "compile for Volta GPU" line
- [x] 9. configuration.nix: no gencode in `NVCC_PREPEND_FLAGS`; the arch belongs
      in the makefile
- [x] 10. Verify before switching, with only the two flags exported: all five
      build with plain `make`, `cuobjdump` lists `sm_75` alone, `hello-world`
      reports compute 7.5, `axpy` and `dot` run, `ger` and `gemm` TEST PASS
- [x] 11. `nixos-rebuild build`: evaluates, built system carries the two-flag string
- [ ] 12. `sudo nixos-rebuild switch`, then re-run step 10 with no CUDA variables set

Existing terminals keep the pre-switch environment: `__NIXOS_SET_ENVIRONMENT_DONE`
is exported, so child shells skip `/etc/set-environment` and never see the new
variable. Open a new terminal, or
`unset __NIXOS_SET_ENVIRONMENT_DONE && . /etc/set-environment`.
