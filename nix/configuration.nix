{ config, lib, pkgs, ... }:

let
  # Kawkab Mono — Arabic monospaced font (https://makkuk.com/kawkab-mono/).
  # nixpkgs ships only a stale 0.1 snapshot, so build the current v0.501
  # release from the project's GitHub instead.
  kawkab-mono = pkgs.stdenvNoCC.mkDerivation {
    pname = "kawkab-mono";
    version = "0.501";

    src = pkgs.fetchzip {
      url = "https://github.com/aiaf/kawkab-mono/releases/download/v0.501/kawkab-mono-0.501.zip";
      sha256 = "1pwhgfvy3jxydrdylzpvcp5823hbcydh29yj1vmk4pxp7ccm0fkh";
    };

    installPhase = ''
      runHook preInstall
      mkdir -p $out/share/fonts/truetype
      find . -name '*.ttf' -exec install -m644 {} $out/share/fonts/truetype/ \;
      runHook postInstall
    '';

    meta = {
      description = "Arabic monospaced (fixed-width) typeface";
      homepage = "https://makkuk.com/kawkab-mono/";
      license = lib.licenses.ofl;
    };
  };

  # binfmt_misc interpreter for type 2 AppImages. writeShellApplication adds its
  # own shebang and a PATH for runtimeInputs, so the repo copy keeps a shebang
  # for direct testing and it is dropped here.
  appimage-binfmt = pkgs.writeShellApplication {
    name = "appimage-binfmt";
    runtimeInputs = with pkgs; [ appimage-run binutils squashfsTools ];
    text = lib.removePrefix "#!/usr/bin/env bash\n" (builtins.readFile ./appimage-binfmt.sh);
  };

  # lazygit from a pinned nixpkgs-unstable revision. The nixos-26.05 channel
  # pins 0.61.1, but common/.config/lazygit/config.yml uses `git.diffRenderers`,
  # which needs >= 0.64 (the old `git.paging` was removed then). Only this one
  # package comes from unstable; the rest of the system stays on 26.05. The
  # rev's lazygit is in cache.nixos.org, so it is fetched, not compiled.
  unstable = import (builtins.fetchTarball {
    url = "https://github.com/NixOS/nixpkgs/archive/4975466d324710c576dc11ad614684e6bd8cad8e.tar.gz";
    sha256 = "1if9h4d8rkgd7a41j978swbixif81iqfd7hk302w0fbd23i9g7y4";
  }) {
    system = pkgs.stdenv.hostPlatform.system;
    # A separate import does not inherit the system's nixpkgs.config;
    # obsidian (unlike lazygit) is unfree, so allow it here too.
    config.allowUnfree = true;
  };
in
{
  imports =
    [
      ./hardware-configuration.nix
    ];

  boot.loader.systemd-boot = {
    enable = true;
    configurationLimit = 2; # ESP is a Windows-created 100M partition; each
    # distinct initrd is ~41M (GPU firmware), kernel ~13M — 2 generations is
    # the most that fit alongside dedup'd files. If a switch ever fails with
    # ENOSPC on /boot, delete the oldest entry's initrd in /boot/EFI/nixos first.
  };
  boot.loader.efi.canTouchEfiVariables = true;

  # Compress the initrd to save space on the tiny EFI partition
  boot.initrd.compressor = "zstd";

  # Swap. This box has 31 GiB RAM and, before this, no swap at all, so when
  # memory filled (Docker + Electron + browsers) the kernel had nothing to
  # evict and OOM-killed Brave (its oom_score_adj=300 makes it first). Two
  # tiers: zram compresses cold anonymous pages in RAM (fast, no disk wear);
  # a bounded disk swapfile catches what compression cannot. See epic 29.
  zramSwap = {
    enable = true;
    # Module defaults used as-is: memoryPercent=50, zstd, priority=5. zram's
    # priority is above the disk device below, so the kernel fills it first.
    # The 50% is the *stored* cap, not RAM use — real usage is the compressed
    # size (~1/2–1/3 for browser/Electron pages).
  };

  # 16 GiB overflow on the root ext4 (199 GiB free). Bounded on purpose: a
  # huge file turns an OOM into SSD thrashing. The default priority is
  # negative, so it stays below zram. Created automatically on activation
  # when missing or a different size.
  swapDevices = [
    { device = "/var/swapfile"; size = 16384; }
  ];

  # Drop cold anonymous pages while zram still has room — reclaim is cheap
  # there, which is the whole point of preventing the OOM kill. Rejected 60
  # (too timid for a zram-first box) and 180 (too aggressive now that a disk
  # tier exists). See epic 29.
  boot.kernel.sysctl."vm.swappiness" = 100;

  networking.hostName = "nixos";

  networking.networkmanager.enable = true;

  time.timeZone = "Africa/Cairo";

  i18n.defaultLocale = "en_US.UTF-8";
  # Arabic locales (glibc) — ar is available for apps/locales alongside en_US.
  i18n.extraLocales = [ "ar_EG.UTF-8/UTF-8" ];

  services.xserver.enable = true;

  services.displayManager.gdm.enable = true;
  services.desktopManager.gnome.enable = true;

  # GNOME (Wayland) sessions take their xkb options from gsettings, not from
  # this option — see programs.dconf below; without that block caps:escape
  # has no effect under GNOME.
  services.xserver.xkb.layout = "us";
  services.xserver.xkb.options = "caps:escape";

  services.pipewire = {
    enable = true;
    pulse.enable = true;
  };

  services.libinput.enable = true;

  # Hybrid GPU (HP ZBook Fury 15 G7). The Intel CometLake UHD 620 at
  # 0000:00:02.0 drives eDP-1 and the GNOME Wayland session. The NVIDIA Quadro
  # T2000 Mobile (TU117, 0000:01:00.0, 4 GiB) has no connected output and is
  # used per application.
  #
  # The proprietary driver is the only route to CUDA, NVDEC/NVENC, OptiX and
  # real clocking: nouveau never reclocks the card, so it stays at boot clocks.
  # `open` selects NVIDIA's open kernel modules, the vendor recommendation for
  # Turing and cached for kernel 6.18.52 (driver 595.71.05).
  hardware.nvidia = {
    open = true;
    prime = {
      offload.enable = true;
      offload.enableOffloadCmd = true; # provides the `nvidia-offload` wrapper
      intelBusId = "PCI:0:2:0";
      nvidiaBusId = "PCI:0:1:0";
    };

    # The external Samsung sits on DP-6 of the T2000 (card0), not on an Intel
    # output, so the discrete GPU owns a display. Without this the driver gets
    # no suspend/resume handling: on resume nv_drm logs "Failed to initialize
    # semaphore for plane fence" and "Failed to apply atomic modeset. Error
    # code: -11", then repeats "Flip event timeout on head 0", and the monitor
    # stays black until reboot (unplug and replug does not recover it). This
    # sets NVreg_PreserveVideoMemoryAllocations=1 and, with the open modules on
    # driver 595, NVreg_UseKernelSuspendNotifiers=1. Before the change the
    # driver reported PreserveVideoMemoryAllocations=2 and
    # UseKernelSuspendNotifiers=0, the built-in defaults, which confirms the
    # module emitted neither.
    powerManagement.enable = true;
  };

  # The nvidia module gates on this list; it is also what builds the driver link
  # farm that exposes nvidia_icd.json to Vulkan clients (Brave WebGPU).
  services.xserver.videoDrivers = [ "nvidia" ];

  # GNOME's "Launch Using Discrete Graphics Card" entry needs this D-Bus
  # service; the nvidia module does not enable it.
  services.switcherooControl.enable = true;

  # The module ships the service but not the package's udev rules, so
  # `30-discrete-gpu.rules` never installs and the `switcheroo-discrete-gpu`
  # tag is missing (switcherooctl reports Discrete: no for both GPUs). GNOME 50
  # keys its menu entry off HasDualGpu, so that works either way, but the
  # D-Bus property should be right for other clients.
  services.udev.packages = [ pkgs.switcheroo-control ];

  # Intel VA-API (iHD) for the display GPU. Without this package libva has no
  # Intel driver at all (vaInitialize fails for both iHD and i965), and the
  # only working driver is nvidia-vaapi-driver from
  # hardware.nvidia.videoAcceleration. Forcing that session wide makes
  # Chromium decode on the T2000 while its compositor runs on Intel: the frame
  # never reaches Skia (eglCreateImage failed 0x00003009, ProduceSkiaGanesh
  # failed to create GL representation), so video playback freezes the tab.
  # With iHD installed libva picks the driver matching the render node and no
  # session wide override is needed. Turing decodes H.264, HEVC and VP9 but
  # not AV1, so Intel QuickSync is the better default for video anyway.
  hardware.graphics.extraPackages = [ pkgs.intel-media-driver ];

  nixpkgs.config.allowUnfree = true;

  # ranger's kitty-graphics query sends `S`, which Ghostty 1.3.x rejects with
  # `EINVAL: invalid data`; ranger aborts before drawing (ranger#3203). Ghostty
  # also rejects ranger's fallback temp-file medium (`t=t`). Treat the EINVAL
  # reply like `EBADF` so ranger uses direct (`t=d`) transmission, which Ghostty
  # accepts (verified in a real Ghostty surface). Drop this overlay once
  # ranger#3203 is fixed upstream; `--replace-fail` fails the build if a
  # ranger bump moves the line.
  nixpkgs.overlays = [
    (final: prev: {
      ranger = prev.ranger.overrideAttrs (old: {
        postPatch = (old.postPatch or "") + ''
          substituteInPlace ranger/ext/img_display.py \
            --replace-fail "elif b'EBADF' in resp:" \
                           "elif b'EBADF' in resp or b'EINVAL' in resp:"
        '';
      });

      # Discord's Electron main process logs via console.warn/info during
      # startup. If stdout is a pipe whose reader already exited, the write
      # raises EPIPE (or EIO, when it is a pty whose master is gone) and
      # Electron shows a modal "A JavaScript error occurred in the main
      # process" dialog instead of starting. Some desktop launchers hand the
      # child exactly that.
      #
      # The guard goes on line 2 of the wrapper, BEFORE its two --run helpers
      # (disable-breaking-updates.py, discord-stage-modules): those inherit the
      # same broken stdout and the Python one dies first with its own
      # BrokenPipeError, so patching only the final `exec -a "$0"` line is not
      # enough. `[ -t 1 ]` keeps output intact when a terminal IS attached.
      # Redirecting to /dev/null costs no diagnostics — Discord still writes
      # ~/.config/discord/logs/ on its own.
      #
      # WORKAROUND for NixOS/nixpkgs#570831 (same one-liner is already on the
      # Darwin side in #532084). Drop this overlay once either lands.
      #
      # NOTE: `sed`, not `substituteInPlace`. In current nixpkgs substituteInPlace
      # is NOT sed — substituteStream() does a literal bash substring replace
      # (${var//pattern/replacement}), so a regex like `1s|...|...|` never
      # matches and --replace-fail aborts the build with "pattern doesn't match
      # anything". sed is also what actually turns \n into a newline there.
      # The grep guard keeps the "fail loudly if a Discord bump moves the
      # shebang" property that --replace-fail gave us.
      discord = prev.discord.overrideAttrs (old: {
        postInstall = (old.postInstall or "") + ''
          f=$out/opt/Discord/Discord
          grep -q '^#! ' "$f" || {
            echo "discord overlay: no shebang found in $f" >&2
            exit 1
          }
          # Capture the whole shebang line and re-emit it verbatim, then append
          # the guard. Anchoring on a bare "#!" would clobber the interpreter
          # path, which is a store path, not /usr/bin/env.
          sed -i '1s|^#! \(.*\)$|#! \1\n[ -t 1 ] \|\| exec > /dev/null 2>\&1|' "$f"
        '';
      });

      # Copyous auto-paste picks its chord from `content_purpose === TERMINAL`;
      # a terminal that never advertises a purpose (WezTerm) got Shift+Insert,
      # which pastes the *primary selection* there instead of the clipboard, so
      # auto-paste inserted stale content for images (always) and text (when
      # sync-primary was off). The patch uses Ctrl+V / Ctrl+Shift+V, keeps
      # images on the raw Ctrl+V, and detects terminals from the focused
      # window's desktop categories. It ships as a sibling of this file (see
      # copyous-terminal-paste/); drop once fixed upstream
      # (boerdereinar/copyous#168, PR #169).
      gnomeExtensions = prev.gnomeExtensions // {
        # The diff targets EGO v9 (upstream 2.0.1) only. Guard instead of pinning:
        # a nixpkgs bump must surface as a loud, actionable failure rather than a
        # cryptic "Hunk #1 FAILED" from `patch` -- and rather than silently
        # freezing copyous at v9, which would hide the upstream fix landing.
        copyous =
          if prev.gnomeExtensions.copyous.version != "9" then
            throw ''
              copyous bumped from 9 to ${prev.gnomeExtensions.copyous.version}.
              Re-check boerdereinar/copyous#168 and PR #169 first: if the terminal
              auto-paste fix landed upstream, delete nix/copyous-terminal-paste/
              together with this guard; otherwise re-port terminal-paste.patch
              against the new version and bump the guard.
            ''
          else
            # The terminal-paste patch is the only change this override needs.
            # nixpkgs' extensionOverrides.nix injects the GIRepository prepends
            # from the final package set, so the libgda6 override below reaches
            # the extension on its own: a rewiring attempt here failed its guard
            # because the injected path was never the pre-overlay one.
            prev.gnomeExtensions.copyous.overrideAttrs (old: {
              patches = (old.patches or []) ++ [ ./copyous-terminal-paste/terminal-paste.patch ];
            });
      };

      # Copyous loads Gda through GIRepository. The generated Gda-6.0.typelib
      # lists libxml2-2.0 as a prerequisite, but nixpkgs' libxml2 ships no
      # typelib (out and dev, checked in 26.05 and unstable), so GJS aborts with
      # "Typelib file for namespace 'libxml2', version '2.0' not found" and the
      # extension falls back to an in-memory database. Copyous only needs the
      # SQLite provider, and none of the GIR-exposed functions that take
      # xmlNodePtr are used, so drop the XML include from the scanner. Drop this
      # override once libxml2 ships a typelib or libgda stops listing it; the
      # grep makes a libgda bump fail loudly instead of silently losing the fix.
      libgda6 = prev.libgda6.overrideAttrs (old: {
        postPatch = (old.postPatch or "") + ''
          grep -q "'libxml2-2.0'" libgda/meson.build || {
            echo "libgda override: libgda/meson.build no longer lists libxml2-2.0" >&2
            exit 1
          }
          sed -i "/'libxml2-2.0'/d" libgda/meson.build
        '';
      });

      # 1.20.4 advertises AvailableCursorModes=0 to clients while the GNOME
      # backend reports 7, so the frontend rejects every cursor mode before a
      # picker can open: Discord gets
      # `org.freedesktop.portal.Error.InvalidArgument: Unavailable cursor mode 2`
      # and "Share Your Screen" appears to do nothing at all. Chromium clients
      # omit `cursor_mode` and never notice, so the bug is system-wide and not
      # Discord-specific.
      #
      # The frontend copies the backend proxy's cursor modes into a file-static
      # snapshot at startup. At login the proxy resolves before the backend owns
      # its bus name, so the snapshot is 0, and the resync signal
      # (`notify::supported-cursor-modes`) names a property the generated proxy
      # does not have, which makes the 0 permanent. The patch drops the
      # snapshot and validates against the proxy instead; glib refills that
      # cache eagerly once the backend claims its name, so by the time a client
      # calls SelectSources the live read is correct. Upstream 1.22.0 reads the
      # live value too.
      #
      # Known leftover, same as upstream: the frontend still advertises 0/0
      # after a racing login, because the per-property notify does not fire on
      # that owner change. `systemctl --user restart xdg-desktop-portal`
      # restores 7/7 until the next login.
      # Logs: ~/.config/discord/logs/discord-webrtc_1.
      xdg-desktop-portal =
        if prev.xdg-desktop-portal.version != "1.20.4" then
          throw ''
            xdg-desktop-portal bumped from 1.20.4 to ${prev.xdg-desktop-portal.version}.
            Re-check src/screen-cast.c first: if validate_cursor_mode() reads the
            mode live (or the impl proxy is bound), the upstream fix landed --
            delete nix/xdg-portal-cursor-modes/ together with this guard.
            Otherwise re-port available-cursor-modes.patch against the new
            version and bump the guard.
          ''
        else
          prev.xdg-desktop-portal.overrideAttrs (old: {
            patches = (old.patches or []) ++ [
              ./xdg-portal-cursor-modes/available-cursor-modes.patch
            ];
          });
    })

    # Brave cannot create a WebGPU adapter on this host: its binary carries no
    # Vulkan loader on the RUNPATH and no ICD search path, so the GPU process
    # dies with "Failed to load 'libvulkan.so.1'" and chrome://gpu reports
    # `vulkan: disabled_off`. `vulkanSupport` adds `Vulkan` to
    # --enable-features (required: a control run without it left
    # requestAdapter() null) and prefixes XDG_DATA_DIRS with the driver link
    # farm, which is how the loader finds intel_icd/nvidia_icd. The loader
    # itself still has to come from the wrapper, hence the LD_LIBRARY_PATH
    # append. Drop that append once the channel's brave depends on
    # vulkan-loader (nixpkgs 26.11 wires it; the pinned unstable rev does not).
    #
    # Pinning the loader to the Intel ICD is also required. With every ICD
    # visible Dawn enumerates the T2000 as well, picks it as the discrete
    # device, then dies in
    # "SharedImageManager::ProduceSkia: Trying to produce a Skia representation
    # from an incompatible backing: CompoundImageBacking" -> "Context was
    # lost", and the GPU process restarts three times until Chromium gives up.
    # WebGL2 is then unavailable and requestAdapter() returns null, which is
    # the "Visual effects require WebGL" dialog in Google Meet. Measured with
    # the ICD list toggled and nothing else changed: intel only -> WebGL2 on,
    # adapter gen-9, compute dispatch 41, zero restarts; intel plus nvidia ->
    # WebGL2 off, adapter null, three restarts. The guard keeps
    # `nvidia-offload brave` working, since that wrapper sets
    # __NV_PRIME_RENDER_OFFLOAD and the Optimus layer then pins the T2000
    # (measured: adapter turing, WebGL2 on, zero restarts).
    #
    # The Vulkan feature is incompatible with --ozone-platform=wayland (Brave
    # logs it). Under Wayland every <video> frame fails with the same ProduceSkia
    # error, so scroll-seeked videos disappear. Measured on an isolated profile
    # with a scroll-seeked video: Wayland plus Vulkan gives 10 to 13 errors per
    # run, Vulkan off gives 0, x11 plus Vulkan gives 0 with webgpu and webgl2
    # both available. Brave therefore runs on Xwayland. Drop the flag when
    # Chromium supports Vulkan on Wayland.
    # See .agents/plans/37-brave-webgpu/.
    (final: prev: {
      brave = (prev.brave.override {
        vulkanSupport = true;
        commandLineArgs = "--ozone-platform=x11";
      }).overrideAttrs (old: {
        preFixup = (old.preFixup or "") + ''
          gappsWrapperArgs+=(
            --prefix LD_LIBRARY_PATH : "${prev.vulkan-loader}/lib"
            --run 'if [ -z "''${__NV_PRIME_RENDER_OFFLOAD:-}" ]; then export VK_LOADER_DRIVERS_SELECT="''${VK_LOADER_DRIVERS_SELECT:-intel*}"; fi'
          )
        '';
      });
    })
  ];

  # Fingerprint reader (HP ZBook Fury 15 G7, Synaptics 06cb:00df) — required
  # for the GNOME lock screen / GDM fingerprint unlock.
  services.fprintd.enable = true;

  # Sensor firmware updates for the same reader: enrollment aborts with
  # BMKT_OUT_OF_MEMORY (104) from the device, and this reader family needs a
  # firmware/IOTA-config update to enroll at all (ArchWiki Laptop/HP).
  services.fwupd.enable = true;

  # Docker engine + CLI (packages.list [dev] "docker").
  virtualisation.docker.enable = true;

  # GPU devices inside containers, via nvidia-container-toolkit CDI.
  hardware.nvidia-container-toolkit.enable = true;

  users.users.assawalhy = {
    isNormalUser = true;
    shell = pkgs.zsh; # default login shell (registered via programs.zsh.enable)
    extraGroups = [ "wheel" "docker" ];
    packages = with pkgs; [
      tree
      proton-vpn
      brave
      firefox
      fzf
      zsh
    ];
  };

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  # Mapped from setup/packages.list (setup-os); entries with no nixpkgs package
  # (pi, kilo, rmem, autopep8, mdtoc) are installed afterwards via their
  # section tool: go install / npm install -g / cargo install / pipx install.
  # gnome-control-center hides Settings → Users → "Fingerprint Login" unless
  # GDM's org.gnome.login-screen schema is on XDG_DATA_DIRS (nixpkgs#561267);
  # without this the enrolment UI never appears even with fprintd working.
  environment.extraInit = ''
    export XDG_DATA_DIRS=$XDG_DATA_DIRS''${XDG_DATA_DIRS:+:}${pkgs.gdm}/share/gsettings-schemas/${pkgs.gdm.name}
  '';

  # Put ~/.local/bin on the PATH of the *whole session*, not just login shells.
  # Without this the graphical session never sees it (GDM does not read
  # ~/.bash_profile, which is the only thing that adds it), so any .desktop
  # with a bare `Exec=opencode-desktop` fails to resolve and GNOME silently
  # does nothing when it is clicked. Also covers the ~/.local/bin tools that
  # GUI launchers might spawn (claude, ajq, composio, plannotator, zg, ...).
  # This writes `export PATH="$HOME/.local/bin:$PATH"` into /etc/set-environment,
  # which the graphical session does inherit (verified: TERMINFO_DIRS, defined
  # in the same file, is present in `systemctl --user show-environment`).
  environment.localBinInPath = true;

  # Prisma's CLI (dukkan-BE, POS-BE) downloads its engines on first use and
  # publishes none for `linux-nixos`, so `schema-engine.gz` 404s and the command
  # dies. That breaks `bun install` outright: its `postinstall` is
  # `prisma generate`, which needs the engine, and without the client every
  # later Prisma command fails too.
  #
  # The variable goes in /etc/set-environment rather than each project's `.env`,
  # so the graphical session inherits it and no terminal needs a manual export.
  # `.env` would also work (prisma.config.ts does `import 'dotenv/config'`, which
  # `postinstall` goes through), but it is gitignored and the value is a store
  # path that changes on every channel bump, so it rots silently.
  #
  # `prisma-engines_7` is 7.8.0 on nixos-26.05 while the projects pin Prisma
  # 7.10.0. Prisma does not reject the skew: `generate`, `migrate deploy` and
  # `migrate diff` were all verified against 7.8.0. `migrate dev` authoring a new
  # migration is the one path not exercised.
  environment.variables.PRISMA_SCHEMA_ENGINE_BINARY = "${pkgs.prisma-engines_7}/bin/schema-engine";

  # Removable NTFS drives: prefer the ntfs-3g FUSE driver over the in-kernel
  # ntfs3. ntfs3 refuses unclean volumes ("volume is dirty and force flag is not
  # set") and its unmount (ntfs3_kill_sb) can hang in D-state, which freezes
  # udisksd and blocks open, unmount, and eject until reboot. ntfs-3g recovers
  # the NTFS journal and is a userspace process that can be killed.
  # Key is udisks2's supported knob (see its mount_options.conf.example).
  services.udisks2.settings."mount_options.conf".defaults.ntfs_drivers = "ntfs";

  # The course makefiles in ~/Projects/akt26/4/akt26_gpu_dev and clangd both
  # assume the FHS CUDA root /usr/local/cuda, which NixOS does not provide.
  # Expose the toolkit there as symlinks: the makefiles take
  # `-L${CUDADIR}/lib64 -lcublas` from it, and clangd is told the same root
  # through --cuda-path. nvcc finds neither on its own: it canonicalizes its
  # own path and looks for include/ beside the store binary rather than beside
  # the symlink, so NVCC_PREPEND_FLAGS supplies that path. See
  # .agents/plans/50-cuda-toolkit-paths.
  systemd.tmpfiles.rules = [
    "d /usr/local 0755 root root -"
    "d /usr/local/cuda 0755 root root -"
    "L+ /usr/local/cuda/bin - - - - ${pkgs.cudaPackages.cudatoolkit}/bin"
    "L+ /usr/local/cuda/include - - - - ${pkgs.cudaPackages.cudatoolkit}/include"
    "L+ /usr/local/cuda/lib - - - - ${pkgs.cudaPackages.cudatoolkit}/lib"
    "L+ /usr/local/cuda/lib64 - - - - ${pkgs.cudaPackages.cudatoolkit}/lib"
    "L+ /usr/local/cuda/nvvm - - - - ${pkgs.cudaPackages.cudatoolkit}/nvvm"
    "L+ /usr/local/cuda/nvml - - - - ${pkgs.cudaPackages.cudatoolkit}/nvml"
  ];

  # nvcc needs two things the FHS layout would have given it for free:
  #
  #   -I/usr/local/cuda/include
  #     The headers. nvcc resolves its own install root from /proc/self/exe, so
  #     it looks beside the store binary and never beside the /usr/local/cuda
  #     symlink. Nothing else in PATH or CUDADIR fixes this.
  #
  #   -Xlinker -rpath -Xlinker /run/opengl-driver/lib
  #     The driver. nvcc links cudart statically by default, and static cudart
  #     dlopen()s "libcuda.so.1" by bare name. NixOS has no /etc/ld.so.cache, so
  #     that lookup fails and cudaGetDevice reports the misleading "CUDA driver
  #     version is insufficient for CUDA runtime version". A RUNPATH on the
  #     binary makes the dlopen find the driver. The cuBLAS assignments never
  #     showed the bug only because libcublas.so.12 already carries that path in
  #     its own RUNPATH.
  #
  # The GPU architecture is not here: the course makefiles name it themselves
  # (sm=75 for the Quadro T2000 in this box).
  environment.sessionVariables.NVCC_PREPEND_FLAGS = lib.concatStringsSep " " [
    "-I/usr/local/cuda/include"
    "-Xlinker -rpath -Xlinker /run/opengl-driver/lib"
  ];

  environment.systemPackages = with pkgs; [
    vim
    wget

    ## [terminal]
    git
    rsync # nix/update-nixos.sh mirrors nix/ to /etc/nixos
    # CLI only. Nothing on this host compiles against libssl, so the headers
    # stay out of a system profile; stdenv.cc covers the build side.
    openssl
    zsh
    tmux
    neovim
    tree-sitter # tree-sitter-cli; nvim-treesitter needs it to compile parsers
    ranger
    fzf
    bat
    tealdeer # tldr pages client; binary is `tldr`
    btop
    htop
    # pipx: this channel's drv isn't cached on cache.nixos.org, so it builds
    # from source, where pipx 1.8.0's own pytest suite fails against 26.05's
    # `packaging` (name@url normalization expects no spaces around @). The
    # wheel itself builds, installs, and passes the import/runtime-deps
    # checks -- only the tests are broken, so skip them. buildPythonPackage
    # gates pytest behind installCheck in this nixpkgs (doCheck isn't even
    # in the drv env -- setting it alone is a no-op), so clear both flags.
    (pipx.overrideAttrs (_: { doCheck = false; doInstallCheck = false; }))
    fd
    xsel
    xclip
    wl-clipboard # wl-copy/wl-paste; Wayland clipboard (in packages.list)
    mousepad # GTK editor; macOS ships TextEdit (in packages.list)
    mise
    luarocks

    ## [extra]
    gh
    delta # git-delta
    jp
    jq
    ffmpeg
    ffmpegthumbnailer # video first frame; preferred over magick's ffmpeg delegate (in packages.list)
    imagemagick # magick; nvim image previews + git textconv downscale (in packages.list)
    ghostscript_headless # magick cannot read or write PDF without the gs CLI (in packages.list)
    poppler-utils # pdftotext/pdftoppm; PDF text + raster for agent inspection (in packages.list)
    pandoc
    file # libmagic; ranger's scope.sh mime type and the preview placeholder line (in packages.list)
    gitui
    unstable.lazygit # >= 0.64 for git.diffRenderers; see the `unstable` let-binding
    lazydocker
    texliveBasic # provides kpsewhich

    ## [gui]
    # Discord: no programs.discord module exists in this nixpkgs, and the
    # package already wraps GTK3/pulse/wayland itself. Unfree — covered by
    # nixpkgs.config.allowUnfree above.
    discord
    mpv
    syncthing
    # Obsidian: 26.05's desktop entry still says StartupWMClass=md.Obsidian,
    # but Electron 43 (Obsidian 1.13.7) reports md.obsidian.Obsidian on
    # Wayland, so GNOME can't associate the window with the dash icon. The
    # pinned unstable rev (see `unstable` above) already has nixpkgs#561709's
    # fix; switch back to pkgs.obsidian once 26.05 backports it.
    unstable.obsidian
    # Claude Desktop: not in nixpkgs; built from Anthropic's Linux beta .deb.
    # No in-app updater on Linux; bump with nix/claude-desktop/update.sh.
    (callPackage ./claude-desktop { })
    typora
    # Deferred (2026-09-24): its source build full-clones the MEGAsync repo and
    # GitHub cancels the long HTTP/2 stream mid-pack ("curl 92 HTTP/2 stream 7
    # reset by server"), blocking the entire switch. Everything else it needs is
    # built. Re-add once the fetch completes — e.g. force git http.version =
    # HTTP/1.1 for sandboxed builders (nix.settings.extra-sandbox-paths + a
    # /homeless-shelter/.gitconfig) — then rebuild.
    # megasync
    zathura
    zathuraPkgs.zathura_pdf_mupdf
    kdePackages.okular
    feh
    nerd-fonts.jetbrains-mono
    nerd-fonts.fira-code
    ghostty
    wezterm

    # GNOME 42+ has no desktop icons; this extension restores them (enabled via
    # the org/gnome/shell dconf default below).
    gnomeExtensions.desktop-icons-ng-ding
    # Keeps browser PiP windows above and on all visible workspaces, working
    # around the missing always-on-top/sticky hints on Wayland. Detection is
    # purely by window title — upstream targets Firefox + Clapper ("may work
    # with few other browsers"); see the dconf note below for the Brave caveat.
    gnomeExtensions.pip-on-top
    # Top-bar system stats (RAM % + CPU package temperature), the GNOME
    # counterpart of macOS Stats. Sensors read /sys/class/hwmon directly
    # (coretemp here), so no lm_sensors/libgtop is needed. Presets live in the
    # org/gnome/shell/extensions/astra-monitor dconf defaults below; enabling
    # follows the org/gnome/shell enabled-extensions entry there.
    gnomeExtensions.astra-monitor
    # Clipboard history / manager (replaces CopyQ). nixpkgs patches this one
    # (extensionOverrides.nix, PR #469919) to load Gda + GSound from its own
    # build inputs, so no system-wide libgda6/gsound wiring is required.
    # Enabled via the org/gnome/shell dconf default below.
    gnomeExtensions.copyous
    # Patches GNOME Shell to skip updates of user extensions. Without it the EGO
    # updater installs copyous 2.1.x into ~/.local/share/gnome-shell/extensions/,
    # which shadows the patched system copy and brings back both the stale
    # primary-selection paste and "Failed to load Gda". See epic 41.
    gnomeExtensions.disable-extension-updates
    # Emoji picker in the top bar. Popup with search, categories and recent
    # emojis; click or Super+. copies/pastes the emoji. Declares shell-version up
    # to 50, this box runs 50.4. Enabled via the org/gnome/shell dconf default
    # below.
    gnomeExtensions.emoji-copy

    ## [gpu]
    # Hybrid GPU diagnostics and CUDA toolchain, see the hardware.nvidia block
    # above. vulkaninfo shows both adapters, vainfo proves the NVDEC path, and
    # the toolkit compiles and runs
    # .agents/plans/38-hybrid-gpu-offload/cuda-smoke.cu as well as the course
    # assignments in ~/Projects/akt26/4/akt26_gpu_dev. It also carries cuBLAS,
    # which the assignments link. No nixpkgs.config.cudaSupport: it rebuilds the
    # CUDA package world.
    libva-utils
    vulkan-tools
    cudaPackages.cudatoolkit
    # Astra Monitor (monitor@astraext.github.io) enumerates GPUs with `lspci`
    # and returns an empty list without it, which is the "No GPU found" label
    # (issue #27, .agents/plans/25-astra-monitor-gpu-detection/). v56 never calls
    # its hasIntelGpuTop() check, so intel-gpu-tools only pays off once upstream
    # lands Intel support.
    pciutils
    intel-gpu-tools

    ## [dev]
    docker
    meld
    lldb
    bats
    maven
    gradle
    bruno
    # mise verifies the signature of every runtime it downloads (node, bun).
    # Without gpg it warns and skips the check, which is the only integrity gate
    # those downloads have.
    gnupg
    gitleaks # secret scanner; CI gate on every branch push (.github/workflows/gitleaks.yml)
    # VS Code, added as a plain package (NOT via programs.vscode): the module
    # always wraps it with vscode-with-extensions and pins --extensions-dir to a
    # read-only store path, which makes UI extension installs fail with ENOENT.
    # This way extensions install into ~/.vscode/extensions.
    vscode.fhs
    stdenv.cc # cc for cargo (rmem); its g++ is also the driver clangd queries
    # make for native builds that need it beyond cc. Specifically node-gyp: pi
    # extensions with a native dep (plannotator's node-pty, ...) compile from
    # source on linux-x64 Node 26 and die with `not found: make` otherwise.
    # stdenv.cc alone is not enough -- the C compiler is there, make is not.
    gnumake

    ## [fonts]
    noto-fonts
    noto-fonts-color-emoji
    noto-fonts-cjk-sans
    # DejaVu carries both Latin and Arabic; the ONLYOFFICE substitution for
    # Latin-only template fonts (epic 27) resolves to it. It must be in
    # fonts.packages so the epic-28 mirror exposes it to the app.
    dejavu_fonts
    # Arabic fonts: naskh (amiri, scheherazade-new), kufi/misc (kacst) and the
    # Kawkab Mono monospace for Arabic.
    amiri
    scheherazade-new
    kacst
    kawkab-mono

    ## [cargo]
    fastmod
    ripgrep
    eza
    broot
    sd
    cargo # toolchain for `cargo install` (rmem)
    rustc

    ## [go]
    glow
    go # toolchain for `go install` (glow)

    ## [npm]
    codex
    biome
    # Toolchain for `npm install -g` (kilo) and the fallback for GUI-launched
    # Mason servers (ts_ls, eslint, pyright, intelephense, prismals), which run
    # through `#!/usr/bin/env node` and never see mise's PATH. Project runtimes
    # come from mise (common/.config/mise/config.toml).
    nodejs

    ## [pip]
    uv # non-interactive fallback; interactive shells get mise's latest
    yt-dlp
    git-fame
    black

    ## tooling
    zenity # GUI password prompt for sudo -A (sudo-askpass)
    usbutils # lsusb
    ntfs3g # mkntfs/ntfsfix/ntfs-3g for removable NTFS

    onlyoffice-desktopeditors
  ];

  services.openssh.enable = true;

  # protonvpn does not work while reverse-path filtering is enabled.
  networking.firewall.checkReversePath = false;

  # System-wide dconf defaults for the GNOME "user" profile. The user database
  # takes precedence over these defaults, so this is the fallback that makes
  # services.xserver.xkb.options effective under GNOME Wayland (the session
  # reads org.gnome.desktop.input-sources, not the X server config).
  programs.dconf.profiles.user.databases = [
    {
      settings = {
        "org/gnome/desktop/input-sources" = {
          xkb-options = [ "caps:escape" ];
        };
        "org/gnome/shell" = {
          # gsettings/dconf *user* values shadow these profile defaults. Once
          # GNOME Shell writes /org/gnome/shell/enabled-extensions into
          # ~/.config/dconf/user, edits here stop taking effect. After a
          # rebuild, run once:
          #   dconf reset /org/gnome/shell/enabled-extensions
          enabled-extensions = [
            "ding@rastersoft.com"
            "pip-on-top@rafostar.github.com"
            "monitor@astraext.github.io"
            "copyous@boerdereinar.dev"
            "disable-extension-updates@swsnr.de"
            "emoji-copy@felipeftn"
          ];
        };
        # The extension only calls make_above() by default; sticking to all
        # visible workspaces (its `stick` key) is opt-in and defaults to false.
        "org/gnome/shell/extensions/pip-on-top" = {
          stick = true;
        };
        # Astra Monitor presets: RAM % on the bar (its default is a bare bar
        # with no number) plus the CPU package temperature sensor. The sensor
        # value is the JSON its prefs dropdown generates: service hwmon, device
        # `coretemp`, sensor label `Package id 0`, attribute input (temp1_input
        # in /sys/class/hwmon). Other sensors (nvme, wifi, pch) are one click
        # away in the extension preferences.
        "org/gnome/shell/extensions/astra-monitor" = {
          memory-header-percentage = true;
          sensors-header-show = true;
          sensors-header-sensor1 = ''{"service":"hwmon","path":["coretemp","Package id 0","input"]}'';
          sensors-header-sensor1-show = true;
        };
      };
    }
  ];

  # Fonts. fontconfig's built-in defaults are DejaVu, which has no (or poor)
  # Arabic coverage — so Arabic serif/monospace text fell back to a random face.
  # Prefer Noto for Latin, and bind the proper Arabic families per generic.
  fonts.fontconfig = {
    defaultFonts = {
      serif = [ "Noto Serif" "Amiri" "Noto Naskh Arabic" ];
      sansSerif = [ "Noto Sans" "Noto Sans Arabic" ];
      monospace = [ "Noto Sans Mono" "Kawkab Mono" ];
      emoji = [ "Noto Color Emoji" ];
    };
    # `strong` outranks the module's `same`-bound defaults, so Arabic requests take precedence.
    localConf = ''
      <?xml version='1.0'?>
      <!DOCTYPE fontconfig SYSTEM 'urn:fontconfig:fonts.dtd'>
      <fontconfig>
        <!-- Arabic serif: classical naskh (Amiri), then Noto Naskh -->
        <match target="pattern">
          <test name="lang" compare="contains"><string>ar</string></test>
          <test name="family"><string>serif</string></test>
          <edit name="family" mode="prepend" binding="strong">
            <string>Amiri</string>
            <string>Noto Naskh Arabic</string>
          </edit>
        </match>
        <!-- Arabic sans -->
        <match target="pattern">
          <test name="lang" compare="contains"><string>ar</string></test>
          <test name="family"><string>sans-serif</string></test>
          <edit name="family" mode="prepend" binding="strong">
            <string>Noto Sans Arabic</string>
          </edit>
        </match>
        <!-- Arabic monospace: Kawkab Mono (the repo's Arabic mono face) -->
        <match target="pattern">
          <test name="lang" compare="contains"><string>ar</string></test>
          <test name="family"><string>monospace</string></test>
          <edit name="family" mode="prepend" binding="strong">
            <string>Kawkab Mono</string>
          </edit>
        </match>
        <!-- Arabic in ANY monospace context, whatever concrete family is
             requested. The rule above only matches a request for the generic
             `monospace` family; apps that ask for a concrete family (e.g.
             Ghostty asks for "JetBrainsMono Nerd Font") bypass it. Monospace
             apps mark the request with spacing=mono, and per-glyph fallback
             puts the missing codepoint in the pattern's charset — so this
             fires for terminal/editor fallback while leaving proportional
             Arabic UI text on Noto Sans Arabic (spacing is not mono there).
             Kawkab covers U+0600-U+06FF only, so that is the range tested. -->
        <match target="pattern">
          <test name="spacing" compare="eq"><const>mono</const></test>
          <test name="charset" compare="contains"><charset><range><int>0x0600</int><int>0x06FF</int></range></charset></test>
          <edit name="family" mode="prepend" binding="strong">
            <string>Kawkab Mono</string>
          </edit>
        </match>
        <!-- ONLYOFFICE Desktop ships only its own fonts (see its AllFonts.js) and
             never sets lang=ar on the font pattern, so a document naming a
             Latin-only face — Word's default complex-script font is often Arial
             — draws .notdef for Arabic. It also uses one font per run, so an
             Arabic-only face would box the Latin in the same run. Substitute a
             both-script face, scoped by prgname so the rest of the system keeps
             Arial → Liberation Sans. DejaVu Sans is the same face Gotenberg
             already falls back to for Arabic in the generated PDF. -->
        <match target="pattern">
          <test name="prgname"><string>DesktopEditors</string></test>
          <test name="family"><string>Arial</string></test>
          <edit name="family" mode="prepend" binding="strong"><string>DejaVu Sans</string></edit>
        </match>
        <match target="pattern">
          <test name="prgname"><string>DesktopEditors</string></test>
          <test name="family"><string>Helvetica</string></test>
          <edit name="family" mode="prepend" binding="strong"><string>DejaVu Sans</string></edit>
        </match>
        <match target="pattern">
          <test name="prgname"><string>DesktopEditors</string></test>
          <test name="family"><string>Segoe UI</string></test>
          <edit name="family" mode="prepend" binding="strong"><string>DejaVu Sans</string></edit>
        </match>
        <match target="pattern">
          <test name="prgname"><string>DesktopEditors</string></test>
          <test name="family"><string>Tahoma</string></test>
          <edit name="family" mode="prepend" binding="strong"><string>DejaVu Sans</string></edit>
        </match>
        <match target="pattern">
          <test name="prgname"><string>DesktopEditors</string></test>
          <test name="family"><string>Calibri</string></test>
          <edit name="family" mode="prepend" binding="strong"><string>DejaVu Sans</string></edit>
        </match>
        <match target="pattern">
          <test name="prgname"><string>DesktopEditors</string></test>
          <test name="family"><string>Times New Roman</string></test>
          <edit name="family" mode="prepend" binding="strong"><string>DejaVu Serif</string></edit>
        </match>
        <match target="pattern">
          <test name="prgname"><string>DesktopEditors</string></test>
          <test name="family"><string>Courier New</string></test>
          <edit name="family" mode="prepend" binding="strong"><string>DejaVu Sans Mono</string></edit>
        </match>
      </fontconfig>
    '';
  };

  # ONLYOFFICE Desktop builds its font list by scanning ~/.local/share/fonts
  # and it skips symlinks. Every NixOS font is a symlink into /nix/store, so the
  # app sees none of them — only its bundled set — and a document that names a
  # Latin-only face draws .notdef for Arabic. Mirror the system fonts as real
  # files (NerdFonts are terminal-only, 269 MB, so skip them) and drop the app's
  # generated font cache so it reindexes on next start.
  systemd.user.services.onlyoffice-system-fonts = {
    description = "Mirror system fonts as real files for ONLYOFFICE Desktop";
    wantedBy = [ "default.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${pkgs.writeShellScript "onlyoffice-system-fonts" ''
        set -euo pipefail
        dst="$HOME/.local/share/fonts/system"
        mkdir -p "$dst"
        ${pkgs.rsync}/bin/rsync -aL --delete --exclude 'NerdFonts' \
          /run/current-system/sw/share/fonts/ "$dst/"
        rm -rf "$HOME/.local/share/onlyoffice/desktopeditors/data/fonts"
      ''}";
    };
  };

  system.stateVersion = "26.05";

  programs.git = {
    enable = true;
    lfs.enable = true;
  };

  programs.zsh.enable = true; # interactive zsh support + /etc/shells entry

  # Zoom. Use the NixOS module, NOT a bare `zoom-us` package: it derives
  # pulseaudioSupport (pipewire + pulse) and gnomeXdgDesktopPortalSupport
  # (GNOME) from the enabled services and feeds xdg-desktop-portal-{gnome,gtk}
  # into Zoom's FHS closure — that is what makes screen share work on Wayland.
  # A raw package gets neither. See .agents/plans/20-zoom-discord.
  programs.zoom-us.enable = true;

  # Run AppImages directly (binfmt). Orca lives as a self-updating
  # ~/Applications/orca-linux.AppImage, outside the Nix store, so its
  # electron-updater can replace the file in place.
  #
  # The module's own binfmt stays off: it points at appimage-run, which forwards
  # every argument to AppRun, so `<appimage> --appimage-extract` launches the app
  # instead of unpacking it. Orca registers its CLI and unpacks its updates that
  # way, so both fail. The registrations below keep the same magic and mask and
  # send type 2 through a wrapper that answers the runtime flags.
  # See .agents/plans/42-orca-appimage-extract.
  programs.appimage = {
    enable = true;
    binfmt = false;
  };

  boot.binfmt.registrations.appimage_type_2 = {
    recognitionType = "magic";
    offset = 0;
    magicOrExtension = ''\x7fELF....AI\x02'';
    mask = ''\xff\xff\xff\xff\x00\x00\x00\x00\xff\xff\xff'';
    interpreter = "${appimage-binfmt}/bin/appimage-binfmt";
  };

  # Type 1 is the legacy ISO payload; the wrapper handles squashfs only.
  boot.binfmt.registrations.appimage_type_1 = {
    recognitionType = "magic";
    offset = 0;
    magicOrExtension = ''\x7fELF....AI\x01'';
    mask = ''\xff\xff\xff\xff\x00\x00\x00\x00\xff\xff\xff'';
    interpreter = "${pkgs.appimage-run}/bin/appimage-run";
  };

  # Foreign (non-Nix) binaries — see .agents/plans/05-foreign-binaries.
  # nix-ld supplies the /lib64/ld-linux interpreter; `libraries` supplies the
  # runtime dlopen() targets those binaries expect (`ldd` does not list them).
  # Do not add `wayland` here — OpenTUI (opencode) would then select its
  # Wayland clipboard backend, which GNOME/Mutter cannot serve, and paste would
  # break again (epic 04 D5). Omitting it keeps OpenTUI on working X11/XWayland.
  programs.nix-ld = {
    enable = true;
    libraries = with pkgs; [
      libxcb # opencode clipboard (X11/XWayland)
      glib # libglib-2.0 / libgobject-2.0 (opencode, claude)
      libsecret # secret storage (opencode, claude)
      alsa-lib # libasound.so.2
      libpulseaudio # libpulse.so.0

      # No gcc entry: the nix-ld module already seeds this list with the gcc
      # libraries, so libstdc++.so.6 is in the nix-ld path already.

      # Playwright's Chromium (prebuilt, `~/.cache/ms-playwright`) — the
      # headless shell and the full binary both dlopen these at startup and
      # die on `libnspr4.so` without them. Runtime .so only: no compiler
      # toolchain is involved, and the `dev` outputs are deliberately not
      # listed. libgbm + libdrm rather than all of `mesa` (narrower closure,
      # no EGL/wayland drivers).
      nspr # libnspr4.so
      nss # libnss3.so / libnssutil3.so / libsmime3.so
      at-spi2-core # libatk-1.0.so.0 / libatk-bridge-2.0.so.0 / libatspi.so.0
      dbus # libdbus-1.so.3
      expat # libexpat.so.1
      libgbm # libgbm.so.1
      libdrm # libdrm.so.2
      libX11 # libX11.so.6 / libX11-xcb.so.1
      libXext # libXext.so.6 — separate package from libX11 in nixpkgs
      libXcomposite # libXcomposite.so.1
      libXdamage # libXdamage.so.1
      libXfixes # libXfixes.so.3
      libXrandr # libXrandr.so.2
      libxi # libXi.so.6 — hermes-agent's cua-driver (computer-use tool).
           # Its own DT_NEEDED (libX11, libXext, libxcb, libXau, libXdmcp)
           # all resolve already, so this one package is the whole gap.
      libxkbcommon # libxkbcommon.so.0

      # The rest of what playwright-cli's bundled Chromium wants. nix-ld indexes
      # only the SONAMEs each listed package itself provides, so a package's own
      # DT_NEEDED entries must be listed too — hence the two groups. Verified
      # against ~/.cache/ms-playwright/chromium-*/chrome-linux64/chrome: with
      # these added, `ldd` reports no unresolved libraries.
      #
      # Do NOT try to fix this with a per-command LD_LIBRARY_PATH instead. Store
      # paths from different closure generations get mixed, and a stale
      # libm.so.6 then fails with `GLIBC_x.y not found` — the exact problem
      # nix-ld exists to solve. `playwright-cli install-browser --with-deps` is
      # no help either: it drives apt/dnf, which NixOS does not have.
      cairo # libcairo.so.2
      pango # libpango-1.0.so.0
      cups # libcups.so.2
      libudev-zero # libudev.so.1
      # --- required by the four above ---
      libpng # libpng16.so.16 (cairo)
      pixman # libpixman-1.so.0 (cairo)
      libXrender # libXrender.so.1 (cairo)
      fontconfig # libfontconfig.so.1 (cairo)
      freetype # libfreetype.so.6 (cairo, pango)
      fribidi # libfribidi.so.0 (pango)
      libthai # libthai.so.0 (pango)
      harfbuzz # libharfbuzz.so.0 (pango)
      avahi # libavahi-common.so.3 / libavahi-client.so.3 (cups)
      gnutls # libgnutls.so.30 (cups)
      zlib # libz.so.1 (cups)
      # libxcb above already supplies libxcb-render.so.0 and libxcb-shm.so.0.
    ];
  };

  # First-login unit that provisions uv's default Python links (python,
  # python3 in ~/.local/bin); NixOS equivalent of setup/steps/91-uv-python.sh.
  systemd.user.services.uv-python = {
    description = "uv default Python (python, python3 links)";
    wantedBy = [ "default.target" ];
    serviceConfig = {
      Type = "oneshot";
      ConditionPathExists = "!%h/.local/bin/python";
      ExecStart = "${pkgs.uv}/bin/uv python install 3 --default";
    };
  };

  # Resolve hardcoded shebang/interpreter paths (/bin/bash, /usr/bin/python3, …)
  # via PATH for scripts shipped by foreign binaries.
  services.envfs.enable = true;

  # python-build-standalone (uv's CPython, and every uv tool: rv, harbor, …)
  # compiles OpenSSL with the default cafile /etc/ssl/cert.pem, which NixOS
  # never creates. Without it ssl.create_default_context() loads zero roots.
  environment.etc."ssl/cert.pem".source = config.security.pki.caBundle;
}
