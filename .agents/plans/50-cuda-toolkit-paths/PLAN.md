# CUDA toolkit paths for the course makefiles and clangd

**Status: DRAFT, awaiting go.** Progress is in [TODO.md](TODO.md).
Extends plan 45 (C++ headers for clangd) to CUDA, keeping its rule: nothing in
the dotfiles may name a `/nix/store` or `/run/current-system` path.

## Problem

In `~/Projects/akt26/4/akt26_gpu_dev`, plain `make` fails with
`cuda_runtime.h: No such file or directory`, and nvim's clangd shows
`unknown type name '__global__'`, undeclared `cudaMalloc`, and missing
`std::fabs`/`std::atoi` in `.cu` buffers.

## Measured facts (2026-10-31, not assumed)

- `/usr/local` does not exist on this host. Every course makefile defaults
  `CUDADIR ?= /usr/local/cuda` and links `-L${CUDADIR}/lib64 -lcublas`.
- The system carries `cuda_nvcc` and `cuda_cudart` 12.9.86 only. No cuBLAS, and
  `cuda_nvcc/include` does not contain `cuda_runtime.h`.
- **nvcc canonicalizes its own path**, so a symlinked toolkit root does not give
  it a sibling `include/`: `/nix/store/...-cuda-merged-12.9/bin/nvcc` and
  `~/.local/cuda/bin/nvcc` both still fail. `NVCC_PREPEND_FLAGS=-I<root>/include`
  is what works (built and ran both assignments with it).
- nix's gcc wrapper bakes `RUNPATH` from every `-L`, so binaries that link
  cuBLAS run with no `LD_LIBRARY_PATH` (verified with `readelf -d` and `ldd`).
- clangd infers CUDA from the `.cu` extension and then asks the driver for
  system includes with `g++ -E -v -x cuda -`. g++ rejects that language, so
  libstdc++ headers never resolve. A small wrapper that rewrites `-x cuda` to
  `-x c++` makes extraction succeed.
- With `Compiler: gxx-cuda` plus `--cuda-path=<toolkit root>` and the wrapper in
  `--query-driver`, `clangd --check` reports **0 errors** on `ger.cu` and
  `gemm.cu` (tested with the real Mason clangd 23.1.0).
- clang searches `/usr/local/cuda` as a default CUDA installation candidate, so
  a real `/usr/local/cuda` needs no `--cuda-path` at all.

## Decisions

1. **Provide `/usr/local/cuda` as a real directory of symlinks** into
   `cudaPackages.cudatoolkit`, created by `systemd.tmpfiles.rules`. It is the FHS
   path that both the course makefiles and clang assume.
   Rejected: pointing `CUDADIR` at a store path (breaks plan 45's portability
   rule and still leaves clangd blind); per-project `.clangd` files (rejected in
   plan 45).
2. **Add `cudaPackages.cudatoolkit` to `environment.systemPackages`** and drop
   the separate `cuda_nvcc`/`cuda_cudart`. The toolkit contains both, so nvcc
   stays on `PATH` and the root is pinned against garbage collection.
   Rejected: adding only `cuda_cublas` (three packages to stitch together, and no
   single root to hand to `-I`, `-L` and clang).
3. **`environment.sessionVariables.NVCC_PREPEND_FLAGS =
   "-I/usr/local/cuda/include"`.** This is the NixOS-specific part: a stock
   distro's nvcc sits inside its own prefix and needs no help.
   Rejected: an nvcc wrapper earlier on `PATH` (same effect, one more moving
   part); `CPATH`/`CPLUS_INCLUDE_PATH` (nvcc ignores them).
4. **Dotfiles: a portable `gxx-cuda` wrapper.** `common/bin/gxx-cuda` rewrites
   `-x cuda` to `-x c++` and execs `g++`. `common/.config/clangd/config.yaml`
   switches `Compiler` to it, and `lsp.lua` adds its absolute `~/bin` path to
   `--query-driver`. No store paths, so the dotfiles stay portable.
5. **No `.zshrc` change.** `CUDADIR` already defaults to `/usr/local/cuda` in the
   makefiles and `RUNPATH` covers runtime, so two exports are not needed.
6. **No makefile change.** `sm` stays 80. This laptop's GPU is sm_75, so a build
   meant to run here uses `make sm=75`. Changing the default is a separate
   decision, listed under Open questions.

## Changes

- `nix/configuration.nix`: swap `cuda_nvcc`/`cuda_cudart` for
  `cudaPackages.cudatoolkit`; add tmpfiles rules for `/usr/local` and
  `/usr/local/cuda/{bin,include,lib,lib64,nvvm,nvml}`; add
  `NVCC_PREPEND_FLAGS` to `environment.sessionVariables`.
- `common/bin/gxx-cuda` (new, executable): the driver wrapper.
- `common/.config/clangd/config.yaml`: `Compiler: gxx-cuda`, comment updated.
- `common/.config/nvim/lua/plugins/lsp.lua`: append the wrapper to the
  `--query-driver` list.

## Verification

- Fresh shell after `sudo nixos-rebuild switch`, no CUDA variables exported:
  plain `make` succeeds in all five assignment directories.
- `make sm=75` and run `3-ger/ger` and `4-gemm/gemm`: both print `TEST PASS`.
- `clangd --check` on `3-ger/ger.cu`, `4-gemm/gemm.cu` and a `bits/stdc++.h`
  C++ file: 0 errors each.
- `which nvcc` resolves and `nvcc --version` reports 12.9.

## Risks

- clang's `/usr/local/cuda` auto-detection comes from LLVM's default candidate
  list; if it misses, add `--cuda-path=/usr/local/cuda` to the clangd config,
  which is still a portable path.
- Replacing `cuda_nvcc`/`cuda_cudart` changes what
  `/run/current-system/sw/bin/nvcc` points at. Same version, but worth a check.
- `/usr/local` becomes a non-store path managed by tmpfiles. It is recreated on
  every boot and every switch.
- `nixos-rebuild switch` is required, and a rollback means reverting one commit.

## Open questions

- Should the five makefiles default to `sm=75` so plain `make` also produces a
  runnable binary on this laptop? Not done here because the assignments target
  Ampere and may be graded elsewhere.
