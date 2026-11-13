# Astra Monitor (monitor@astraext.github.io), built from source instead of
# nixpkgs' gnomeExtensions.astra-monitor. Three reasons, see
# .agents/plans/53-astra-monitor-local/PLAN.md:
#
#  1. nixpkgs 26.05 pins EGO v56 = upstream release 39 (March 2026). Releases
#     40-43 carry the NVIDIA ~10 s stutter fix (#211), the menu and memory
#     lifecycle work, posix_spawn() as the default subprocess backend, the
#     lspci last-device "No GPU found" fix (#235) and Intel GPU support (i915).
#  2. nixpkgs' extensionOverrides.nix prepends the libgtop typelib path for
#     Vitals and system-monitor-next, but not for Astra Monitor, so on NixOS
#     `import('gi://GTop')` fails and every GTop data source silently falls
#     back to /proc walks and subprocesses. postPatch injects the path here.
#  3. ./patches/*.patch are local fixes on top of upstream (the first one stops
#     the storage header spawning lsblk twice per tick).
#
# Development: `localSrc` builds a working tree instead of the pinned rev, which
# is what nix/astra-monitor/dev.sh does. Patches are not applied to a localSrc:
# the working tree is expected to carry them as commits already.
{ stdenvNoCC
, lib
, fetchFromGitHub
, typescript
, glib
, gettext
, libgtop
, localSrc ? null
}:

let
  uuid = "monitor@astraext.github.io";
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "gnome-shell-extension-astra-monitor";
  # Upstream release 43 is EGO version 62 (metadata.json "version").
  version = "43-unstable-2026-10-12";

  src =
    if localSrc != null then
      lib.cleanSourceWith {
        src = localSrc;
        # Keep the dev tree's npm install and tsc output out of the build.
        filter = path: _type:
          !(builtins.elem (baseNameOf path) [ "node_modules" "build" "dist" ".git" ]);
      }
    else
      fetchFromGitHub {
        owner = "AstraExt";
        repo = "astra-monitor";
        rev = "134327199e48f40d7f2371de46d8e2aea32ab09d";
        hash = "sha256-1/1kTMc0ycpskDXMehvYXUbvluZxPNYly9KpnFxV/DE=";
      };

  # Every patches/*.patch in name order: `dev.sh export` writes them as a
  # numbered `git format-patch` series, so there is no list to keep in sync.
  patches = lib.optionals (localSrc == null) (
    map (name: ./patches + "/${name}")
      (lib.sort lib.lessThan
        (lib.filter (lib.hasSuffix ".patch") (lib.attrNames (builtins.readDir ./patches))))
  );

  nativeBuildInputs = [ typescript glib gettext ];

  # The import is the single place GTop is loaded (Utils.initializeGTop, shared
  # by the shell and the prefs process). The grep makes an upstream refactor
  # fail the build instead of silently dropping GTop again.
  postPatch = ''
    f=src/utils/utils.ts
    grep -q "const res = await import('gi://GTop');" "$f" || {
      echo "astra-monitor: Utils.initializeGTop no longer imports gi://GTop this way" >&2
      exit 1
    }
    substituteInPlace "$f" --replace-fail \
      "const res = await import('gi://GTop');" \
      "const { default: GIRepository } = await import('gi://GIRepository');
            GIRepository.Repository.dup_default().prepend_search_path('${libgtop}/lib/girepository-1.0');
            const res = await import('gi://GTop');"
  '';

  # Upstream type-checks against the @girs npm packages (~300 MB of dev
  # dependencies). The emitted JS does not depend on them, so transpile only;
  # nix/astra-monitor/dev.sh runs the full type check in the working tree.
  buildPhase = ''
    runHook preBuild
    tsc --noCheck --incremental false
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    dir=$out/share/gnome-shell/extensions/${uuid}
    mkdir -p "$dir"
    cp -r build/. "$dir/"
    cp -r metadata.json stylesheet.css LICENSE schemas icons "$dir/"
    glib-compile-schemas "$dir/schemas"
    for po in po/*.po; do
      lang=$(basename "$po" .po)
      mkdir -p "$dir/locale/$lang/LC_MESSAGES"
      msgfmt -o "$dir/locale/$lang/LC_MESSAGES/${uuid}.mo" "$po"
    done
    runHook postInstall
  '';

  passthru.extensionUuid = uuid;

  meta = {
    description = "Performance-focused system monitor for the GNOME Shell top bar";
    homepage = "https://github.com/AstraExt/astra-monitor";
    license = lib.licenses.gpl3Plus;
    platforms = lib.platforms.linux;
  };
})
