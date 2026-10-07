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
        copyous = prev.gnomeExtensions.copyous.overrideAttrs (old: {
          patches = (old.patches or []) ++ [ ./copyous-terminal-paste/terminal-paste.patch ];
        });
      };
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

  # Removable NTFS drives: prefer the ntfs-3g FUSE driver over the in-kernel
  # ntfs3. ntfs3 refuses unclean volumes ("volume is dirty and force flag is not
  # set") and its unmount (ntfs3_kill_sb) can hang in D-state, which freezes
  # udisksd and blocks open, unmount, and eject until reboot. ntfs-3g recovers
  # the NTFS journal and is a userspace process that can be killed.
  # Key is udisks2's supported knob (see its mount_options.conf.example).
  services.udisks2.settings."mount_options.conf".defaults.ntfs_drivers = "ntfs";

  environment.systemPackages = with pkgs; [
    vim
    wget

    ## [terminal]
    git
    rsync # nix/update-nixos.sh mirrors nix/ to /etc/nixos
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
    imagemagick # magick; nvim image previews + git textconv downscale (in packages.list)
    pandoc
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

    ## [dev]
    docker
    meld
    lldb
    bats
    maven
    gradle
    bun
    # VS Code, added as a plain package (NOT via programs.vscode): the module
    # always wraps it with vscode-with-extensions and pins --extensions-dir to a
    # read-only store path, which makes UI extension installs fail with ENOENT.
    # This way extensions install into ~/.vscode/extensions.
    vscode.fhs
    stdenv.cc # compiler wrapper: cargo invokes `cc`, cgo invokes `gcc` (rmem, pi)

    ## [fonts]
    noto-fonts
    noto-fonts-color-emoji
    noto-fonts-cjk-sans
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
    go # toolchain for `go install` (pi)

    ## [npm]
    codex
    biome
    nodejs # toolchain for `npm install -g` (kilo)

    ## [pip]
    uv
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
      </fontconfig>
    '';
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
}
