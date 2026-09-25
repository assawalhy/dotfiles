# TODO

- [x] diagnose: fontconfig `monospace` rule doesn't fire for concrete families
- [x] rule out app-level fix; user wants system-global
- [x] find a fontconfig rule that catches monospace requests without hijacking Arabic serif/sans
- [x] `configuration.nix`: add spacing=mono + charset U+0600-U+06FF → Kawkab rule
- [x] remove the Ghostty-only `config.ghostty` and revert its home link
- [x] validate: `nix-instantiate --parse` OK
- [x] rebuild (stage `/etc/nixos`, switch)
- [x] verify: live `fc-match` matrix (concrete-family Arabic → Kawkab; primary/serif/sans unchanged)
- [ ] verify visual: Arabic in a new terminal is fixed-width
- [x] commit (scoped to epics 05/06 via a temporary index; other sessions' staged work left untouched)
