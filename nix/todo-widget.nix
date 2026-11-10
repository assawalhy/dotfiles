# Todo Widget — GNOME Shell desktop todo list (Hamza-Djellal/todo-widget).
# Not on extensions.gnome.org, so nixpkgs has no gnomeExtensions entry. The
# repo commits the built extension.zip in the same commit as src/, and the zip's
# metadata matches the repo's, so package that artifact instead of rebuilding
# the TypeScript: a from-source build needs npmDepsHash plus the @girs dev
# dependency tree (~300 MB) to produce the same five files.
{ stdenvNoCC
, lib
, fetchFromGitHub
, unzip
, glib
}:

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "gnome-shell-extension-todo-widget";
  version = "1.3.0";

  src = fetchFromGitHub {
    owner = "Hamza-Djellal";
    repo = "todo-widget";
    rev = "0d36c7399cb9abc6de79a27dfb0b8128ff045197";
    hash = "sha256-VIf2pw0kBXvUQs4oVhOnNNbih6V4OtCFCYvDasr95IU=";
  };

  nativeBuildInputs = [ unzip glib ];
  # The repo's Makefile default target is `install`, which runs `npm run build`.
  # Nothing may build here: the committed zip already has the compiled output.
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    dir=$out/share/gnome-shell/extensions/todoWidget@Hamza-Djellal.github.com
    mkdir -p "$dir"
    unzip -o extension.zip -d "$dir"
    glib-compile-schemas "$dir/schemas"
    runHook postInstall
  '';

  passthru.extensionUuid = "todoWidget@Hamza-Djellal.github.com";

  meta = {
    description = "Todo list desktop widget for GNOME Shell";
    homepage = "https://github.com/Hamza-Djellal/todo-widget";
    license = lib.licenses.gpl3Plus;
    platforms = lib.platforms.linux;
  };
})
