# Official MEGA desktop client, repackaged from MEGA's own Ubuntu 24.04 .deb.
# nixpkgs' megasync builds from a full clone of github.com/meganz/MEGAsync.git,
# which fails mid-pack here, and being unfree it never has a binary cache entry.
# To update, run nix/megasync/update.sh.
{
  lib,
  stdenv,
  fetchurl,
  dpkg,
  autoPatchelfHook,
  qt5,
  libxcb,
  xdg-utils,
}:

let
  sources = {
    x86_64-linux = {
      debArch = "amd64";
      hash = "sha256-wdPFy5j3uFPYhA4sMbBw8nLek7RQI8BuWEaCJ7EpqPY=";
    };
  };

  source =
    sources.${stdenv.hostPlatform.system}
      or (throw "megasync is not packaged for ${stdenv.hostPlatform.system}");
in
stdenv.mkDerivation (finalAttrs: {
  pname = "megasync";
  version = "6.7.0-1.1";

  src = fetchurl {
    url = "https://mega.nz/linux/repo/xUbuntu_24.04/amd64/megasync_${finalAttrs.version}_${source.debArch}.deb";
    inherit (source) hash;
  };

  nativeBuildInputs = [
    dpkg
    autoPatchelfHook
    qt5.wrapQtAppsHook
  ];

  buildInputs = with qt5; [
    qtbase
    qtdeclarative
    qtsvg
    qtx11extras
    qtquickcontrols
    qtquickcontrols2
    qtgraphicaleffects
  ] ++ [ libxcb ];

  dontConfigure = true;
  dontBuild = true;
  dontStrip = true;

  unpackPhase = ''
    runHook preUnpack
    dpkg-deb --fsys-tarfile "$src" | tar --extract --file - --no-same-permissions
    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall

    install -Dm755 usr/bin/megasync usr/bin/mega-desktop-app-gfxworker -t "$out/bin"
    install -d "$out/share" "$out/lib/megasync"
    cp -a opt/megasync/lib/. "$out/lib/megasync/"
    cp -a usr/share/megasync usr/share/icons usr/share/applications usr/share/doc "$out/share/"

    substituteInPlace "$out/share/applications/megasync.desktop" \
      --replace-fail "TryExec=megasync" "TryExec=$out/bin/megasync" \
      --replace-fail "Exec=megasync" "Exec=$out/bin/megasync"
    printf '%s\n' "StartupWMClass=megasync" >> "$out/share/applications/megasync.desktop"

    runHook postInstall
  '';

  preFixup = ''
    addAutoPatchelfSearchPath ${placeholder "out"}/lib/megasync
  '';

  qtWrapperArgs = [
    "--prefix PATH : ${lib.makeBinPath [ xdg-utils ]}"
    "--set QT_QPA_PLATFORM xcb"
  ];

  meta = {
    description = "Easy automated syncing between your computers and your MEGA Cloud Drive";
    homepage = "https://mega.io/desktop";
    license = lib.licenses.unfreeRedistributable;
    mainProgram = "megasync";
    platforms = builtins.attrNames sources;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    maintainers = [ ];
  };
})
