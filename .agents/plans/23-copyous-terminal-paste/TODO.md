# TODO — Copyous terminal auto-paste

- [x] epic files created (this dir)
- [x] upstream branch: `clipboard.ts` — chord by content type + terminal detection
- [x] upstream branch: `clipboardDialog.ts` — capture paste target before pushModal
- [x] typecheck + lint branch (tsc/eslint/prettier)
- [x] file upstream issue (WezTerm stale PRIMARY paste) → #168
- [x] fork + push + open PR (references #124) → #169
- [x] local: `copyous-terminal-paste/terminal-paste.patch` (real diff) + a
      relative `patches = [ ./copyous-terminal-paste/... ]` overlay in
      `nix/configuration.nix` (epic 24 moved the config into `nix/`)
- [x] local: user-dir extension installed as a patched copy (immediate fix)
- [x] validate: overlay builds end-to-end (`nixos-rebuild build` → exit 0,
      patched extension byte-identical to the reference tree)
- [x] deploy: `nix/update-nixos.sh` (epic 24) — switched to
      `3dxlrq9ykx6jlnkkzd3ibaq5ylyyk53l`, running system extension patched
- [ ] re-login → extension loads (user-dir copy takes precedence over the system one)
- [ ] verify: image auto-paste in opencode → `[Image 1]`
- [ ] verify: `sync-primary=false` text auto-paste → correct item
- [ ] verify: shell text still pastes; GUI unaffected
- [x] commit dotfiles — `3bddf16` (committed ahead of on-device verification)
