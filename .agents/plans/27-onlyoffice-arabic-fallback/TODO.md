# TODO — epic 27

- [x] diagnose: Gotenberg PDF renders Arabic; ONLYOFFICE draws `.notdef` for `w:cs="Arial"`
- [x] probe `lang=ar` fontconfig rule → **fails**: ONLYOFFICE sends `family:"Arial", lang:"en"`, never `ar`; rule reverted
- [x] probe document `w:cs` → ONLYOFFICE honours it but uses one font per run; Arabic-only face would box the Latin
- [x] explain font list: ONLYOFFICE indexes only its bundled fonts (16); regenerating the cache adds no system fonts
- [x] add `prgname="DesktopEditors"` + Latin-only-family → DejaVu rules to `fonts.fontconfig.localConf`
- [x] `nix-instantiate --parse nix/configuration.nix` OK
- [x] probe in-app: rule fires (123× `Prepend "DejaVu Sans"`); plain `Arial` still Liberation Sans
- [x] probe visual: user confirmed (go) — Arabic shows in the `FONTCONFIG_FILE` instance
- [x] rebuild + switch via `nix/update-nixos.sh` (6 derivations, activated)
- [x] verify live: `Arial:prgname=DesktopEditors` → DejaVu Sans; plain `Arial` still Liberation Sans
- [x] commit (`3cf8bff`)
