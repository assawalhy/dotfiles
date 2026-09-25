# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).

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
  }) { system = pkgs.stdenv.hostPlatform.system; };
in
{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
    ];

  # Use the systemd-boot EFI boot loader.
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

  networking.hostName = "nixos"; # Define your hostname.

  # Configure network connections interactively with nmcli or nmtui.
  networking.networkmanager.enable = true;

  # Set your time zone.
  time.timeZone = "Africa/Cairo";

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";
  # Arabic locales (glibc) — ar is available for apps/locales alongside en_US.
  i18n.extraLocales = [ "ar_EG.UTF-8/UTF-8" ];
  # console = {
  #   font = "Lat2-Terminus16";
  #   keyMap = "us";
  #   useXkbConfig = true; # use xkb options in tty.
  # };

  # Enable the X11 windowing system.
  services.xserver.enable = true;

  services.displayManager.gdm.enable = true;
  services.desktopManager.gnome.enable = true;

  # Configure keymap in X11 / the display manager.
  # NOTE: GNOME (Wayland) sessions take their xkb options from gsettings, not
  # from this option — see programs.dconf below and the gsettings call made in
  # the session, otherwise caps:escape appears to "not work".
  services.xserver.xkb.layout = "us";
  services.xserver.xkb.options = "caps:escape";

  # Enable CUPS to print documents.
  # services.printing.enable = true;

  # Enable sound.
  # services.pulseaudio.enable = true;
  # OR
  services.pipewire = {
    enable = true;
    pulse.enable = true;
  };

  # Enable touchpad support (enabled in most desktopManager).
  services.libinput.enable = true;

  nixpkgs.config.allowUnfree = true;

  # Fingerprint reader (HP ZBook Fury 15 G7, Synaptics 06cb:00df) — required
  # for the GNOME lock screen / GDM fingerprint unlock.
  services.fprintd.enable = true;

  # Docker engine + CLI (packages.list [dev] "docker").
  virtualisation.docker.enable = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.assawalhy = {
    isNormalUser = true;
    shell = pkgs.zsh; # default login shell (registered via programs.zsh.enable)
    extraGroups = [ "wheel" "docker" ]; # Enable ‘sudo’ and docker.
    packages = with pkgs; [
      tree
      proton-vpn
      brave
      fzf
      zsh
    ];
  };

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  # programs.firefox.enable = true;

  # List packages installed in system profile.
  # You can use https://search.nixos.org/ to find more packages (and options).
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
  # set") and its unmount (ntfs3_kill_sb) can wedge the kernel in D-state, which
  # freezes udisksd and blocks open/unmount/eject until reboot. ntfs-3g recovers
  # the NTFS journal transparently and is a killable userspace process.
  # Key is udisks2's supported knob (see its mount_options.conf.example).
  services.udisks2.settings."mount_options.conf".defaults.ntfs_drivers = "ntfs";

  environment.systemPackages = with pkgs; [
    vim
    wget

    ## [terminal]
    git
    zsh
    tmux
    neovim
    tree-sitter # tree-sitter-cli; nvim-treesitter needs it to compile parsers
    ranger
    fzf
    bat
    tealdeer # tldr pages client; binary is `tldr`
    btop # resource monitor (TUI)
    htop # process viewer
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
    pandoc
    gitui
    unstable.lazygit # >= 0.64 for git.diffRenderers; see the `unstable` let-binding
    texliveBasic # provides kpsewhich

    ## [gui]
    mpv
    syncthing
    obsidian
    typora
    copyq
    # Deferred (2026-09-24): its source build full-clones the MEGAsync repo and
    # GitHub cancels the long HTTP/2 stream mid-pack ("curl 92 HTTP/2 stream 7
    # reset by server"), blocking the entire switch. Everything else it needs is
    # built. Re-add once the fetch survives — e.g. force git http.version =
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
    # GNOME 42+ has no desktop icons; this extension restores them (enabled via
    # the org/gnome/shell dconf default below).
    gnomeExtensions.desktop-icons-ng-ding

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
    stdenv.cc # compiler wrapper: cargo wants `cc`, cgo wants `gcc` (rmem, pi)

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

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  services.openssh.enable = true;

  # for protonvpn to work
  networking.firewall.checkReversePath = false;

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # System-wide dconf defaults for the GNOME "user" profile. The user database
  # wins over these defaults, so this is the fallback that makes
  # services.xserver.xkb.options actually effective under GNOME Wayland (the
  # session reads org.gnome.desktop.input-sources, not the X server config).
  programs.dconf.profiles.user.databases = [
    {
      settings = {
        "org/gnome/desktop/input-sources" = {
          xkb-options = [ "caps:escape" ];
        };
        # Desktop Icons NG (DING) — GNOME 50 shows no desktop icons on its own.
        "org/gnome/shell" = {
          enabled-extensions = [ "ding@rastersoft.com" ];
        };
      };
    }
  ];

  # NOTE: programs.vscode is intentionally NOT used — it wraps VS Code with
  # vscode-with-extensions and forces a read-only --extensions-dir, so
  # installing extensions from the UI fails. vscode.fhs is in
  # environment.systemPackages instead (see [dev]).

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
    # `strong` beats the module's `same`-bound defaults, so Arabic requests win.
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

  # Copy the NixOS configuration file and link it from the resulting system
  # (/run/current-system/configuration.nix). This is useful in case you
  # accidentally delete configuration.nix.
  # system.copySystemConfiguration = true;

  # This option defines the first version of NixOS you have installed on this particular machine,
  # and is used to maintain compatibility with application data (e.g. databases) created on older NixOS versions.
  #
  # Most users should NEVER change this value after the initial install, for any reason,
  # even if you've upgraded your system to a new NixOS release.
  #
  # This value does NOT affect the Nixpkgs version your packages and OS are pulled from,
  # so changing it will NOT upgrade your system - see https://nixos.org/manual/nixos/stable/#sec-upgrading for how
  # to actually do that.
  #
  # This being lower than the current NixOS release does NOT mean your system is
  # out of date, out of support, or vulnerable.
  #
  # Do NOT change this value unless you have manually inspected all the changes it would make to your configuration,
  # and migrated your data accordingly.
  #
  # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
  system.stateVersion = "26.05"; # Did you read the comment?

  programs.git = {
    enable = true;
    lfs.enable = true;
  };

  programs.zsh.enable = true; # interactive zsh support + /etc/shells entry

  # Foreign (non-Nix) binaries — see .agents/plans/05-foreign-binaries.
  # nix-ld supplies the /lib64/ld-linux interpreter; `libraries` supplies the
  # runtime dlopen() targets those binaries expect (invisible to `ldd`).
  # NOTE: do NOT add `wayland` here — OpenTUI (opencode) would then select its
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
    ];
  };

  # Resolve hardcoded shebang/interpreter paths (/bin/bash, /usr/bin/python3, …)
  # via PATH for scripts shipped by foreign binaries.
  services.envfs.enable = true;
}
