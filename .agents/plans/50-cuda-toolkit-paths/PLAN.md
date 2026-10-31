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

## Phase 2: the binaries would not run

Compiling was only half of it. Two runtime failures surfaced once `make` worked,
both found by running the binaries rather than trusting the build.

**Driver discovery.** `nvcc` links `cudart` statically by default, and static
cudart `dlopen`s `libcuda.so.1` by bare name. NixOS has no `/etc/ld.so.cache`,
so that lookup fails and `cudaGetDevice` returns the misleading *"CUDA driver
version is insufficient for CUDA runtime version"* (error 35) on a 595.71.05
driver. `ger` and `gemm` had never shown it only because `libcublas.so.12`
carries `/run/opengl-driver/lib` in its own RUNPATH. Fixed by prepending
`-Xlinker -rpath -Xlinker /run/opengl-driver/lib` to `NVCC_PREPEND_FLAGS`, which
puts the path on the binary itself instead of mutating `LD_LIBRARY_PATH`
globally.

**Architecture.** With the driver reachable the real error appeared: *"no kernel
image is available for execution on the device"*. The makefiles targeted
`sm=80` and the Quadro T2000 is `sm=75`. `compute_80` PTX cannot run on `sm_75`,
so no flag ordering could have saved it. The five makefiles now default to
`sm=75`: native SASS here, and `compute_75` PTX still JITs upward on Ampere or
newer, so one default covers both. The architecture lives in the makefile, not
in a hidden environment variable.

**clangd, corrected.** clangd does not find the toolkit from `/usr/local/cuda`
on its own. It locates the SDK from the `nvcc` in PATH, and
`/run/current-system/sw/bin/nvcc` resolves into the `cuda_nvcc` derivation,
which ships no `cuda_runtime.h`. The clangd config therefore passes
`--cuda-path=/usr/local/cuda` in a block scoped to `.*\.(cu|cuh)$`, since the
flag is an unused argument for plain C++.

**Stale terminals.** `__NIXOS_SET_ENVIRONMENT_DONE` is exported, so shells
started before a switch never source the new `/etc/set-environment`. Any
terminal open across the switch keeps the old environment until it runs
`unset __NIXOS_SET_ENVIRONMENT_DONE && . /etc/set-environment`.

## Verification

- Fresh shell after `sudo nixos-rebuild switch`, no CUDA variables exported:
  plain `make` succeeds in all five assignment directories.
- `make` and run `3-ger/ger` and `4-gemm/gemm`: both print `TEST PASS`.
- `cuobjdump -lelf` on a built binary lists `sm_75` only, no `sm_80`.

## Risks

- Replacing `cuda_nvcc`/`cuda_cudart` changes what
  `/run/current-system/sw/bin/nvcc` points at. Same version, but worth a check.
- `/usr/local` becomes a non-store path managed by tmpfiles. It is recreated on
  every boot and every switch.
- `nixos-rebuild switch` is required, and a rollback means reverting one commit.
- The rpath in `NVCC_PREPEND_FLAGS` applies to every nvcc link on this host.
  Harmless for binaries that already resolve the driver, and it is what static
  cudart needs.
- `sm=75` in the makefiles means a grader on an Ampere GPU runs the
  `compute_75` PTX through the JIT rather than native `sm_80` SASS. Slower, but
  it runs. `make sm=80` overrides it per build.

## Open questions

- None. The makefiles now default to `sm=75`; `make sm=80` still works when
  building for an Ampere host.

