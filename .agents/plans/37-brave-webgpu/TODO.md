# TODO — Brave WebGPU

Drafted 2026-10-17. Shipped with epic 38 in generation 49; the runtime probes
below wait for the reboot.
See [PLAN.md](PLAN.md). Runs after epic
[38](../38-hybrid-gpu-offload/PLAN.md), which changes the Vulkan ICDs.

- [x] wait for epic 38 (hybrid GPU driver), so the ICD set is final. Folded into
      epic 38's single deploy instead of a second one: generation 49 carries
      both paths, and the runtime probes below still wait for the reboot.
- [x] add the brave overlay to `nixpkgs.overlays` in `nix/configuration.nix`
      (D1, D2)
- [x] deploy: `nix/update-nixos.sh` (the same activation as epic 38)
- [x] check the generated wrapper carries the `Vulkan` feature, the
      `/run/opengl-driver/share` XDG_DATA_DIRS prefix and the vulkan-loader
      `LD_LIBRARY_PATH` entry (D1, D2). Verified in the rebuilt
      `/nix/store/ywbkbrwhv00g0hv598gv4mq5rd8490aq-brave-1.95.104`: the exec line
      enables `AcceleratedVideoDecodeLinuxGL,AcceleratedVideoEncoder,Vulkan`,
      `XDG_DATA_DIRS` is prefixed with `/run/opengl-driver/share`, and
      `LD_LIBRARY_PATH` gains `vulkan-loader-1.4.341.0/lib`.
- [x] probe the deployed wrapper: adapter non-null, device ok, dispatch 41, and
      record which adapter Dawn picked (D4). It failed: with every ICD visible
      Dawn picked the T2000, ProduceSkia rejected the backing, the GPU process
      restarted three times, and both WebGL2 and WebGPU went away. See the
      second-failure section in PLAN.md.
- [x] probe `nvidia-offload brave` over CDP and confirm it pins the NVIDIA
      adapter (D4): adapter turing, WebGL2 on, dispatch 41, zero restarts.
- [ ] check Brave video decode in `chrome://gpu` and on a real video, and record
      whether the Vulkan flag broke it (D6)
- [x] pin the loader to the Intel ICD from the wrapper (D8), so Dawn stops
      creating a device on the T2000 and the shared image crash is gone. Guarded
      by `__NV_PRIME_RENDER_OFFLOAD` so `nvidia-offload brave` still reaches the
      T2000. Checked: the built wrapper carries the `--run` line; plain launch
      gives WebGL2 on, adapter gen-9, dispatch 41, zero restarts; the offload
      env gives adapter turing, dispatch 41, zero restarts.
- [ ] deploy the overlay change and re-run the probe on the deployed wrapper
- [ ] user: confirm Meet backgrounds, or WebGPU on a real page
      (e.g. webgpureport.org)
- [ ] file a GitHub issue for this symptom and link it from PLAN.md
