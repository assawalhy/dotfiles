# TODO — terminal image previews (#10)

- [x] epic files created (this dir)
- [x] `common/bin/git-img-textconv`: bash textconv (portable base64, magick ≤1000px downscale, 25 MB cap)
- [x] `common/bin/git-img-pager`: pager wrapper (text → delta, OSC 1337 lines raw, ≤4 MiB scan, ANSI-color tolerant)
- [x] `common/bin/git-img-preview`: lazygit helper (image → `git diff HEAD` through the pager; no diff → show file; non-image → text diff)
- [x] `common/.config/git/attributes` (raster globs `diff=img`) + `common/.gitconfig` (`core.attributesFile`, `diff.img.textconv`, pager with no-python delta fallback)
- [x] CLI verify (fixture repo, pty): OSC count intact, delta ANSI present, text-only diff unchanged, mixed order correct; preview script verified for modified/untracked/unchanged image + text
- [x] `common/.config/lazygit/config.yml`: customCommands `I` (files) → `git-img-preview`, `output: terminal` (schema-validated)
- [x] nvim `lua/plugins/images.lua`: snacks image-only spec + `<leader>ip` hover (plugin installed; lazy-lock pinned)
- [x] nvim `lua/config/nontext.lua` + `init.lua` require: `BufReadCmd` ext list, `BufReadPost` NUL sniff, ui.select → xdg-open/keep
- [x] nvim README: image preview + non-text rows
- [x] nvim verify headless: 11/11 checks pass — prompt + `vim.ui.open` + buffer wipe, keep-reload, uppercase ext, NUL sniff, png/text untouched, snacks loads, `supports_terminal` with `SNACKS_WEZTERM=1`
- [x] `setup/packages.list` + `configuration.nix`: `imagemagick check:magick p2` (parse OK; repo→/etc diff = only this line)
- [x] backup + copy `configuration.nix` to `/etc/nixos`, `nixos-rebuild switch`, `magick -version`
  — backup `configuration.nix.bak-20261003-055252`, rebuild exit 0, ImageMagick 7.1.2-31
- [x] `link-files --fix --yes`; `link-files --audit` clean (76 links correct)
- [x] `bats tests/link-files.bats` (99 ok, 0 not ok) + `bats tests/select.bats` (5 ok)
- [x] final checks re-run after all edits: audit clean, bats 99/0 + 5 ok, py_compile + bash -n OK, snacks `supports_terminal` true
- [ ] user visual verification in `/tmp/opencode/visual-fixture` (dirty: `shot.png` + `notes.txt`):
      `git diff` (inline image + delta text), lazygit `I` on shot.png, `nvim shot.png` (float),
      `nvim doc.pdf` / `clip.mp4` (xdg-open prompt); `shot.jpg` for the jpeg path
- [ ] commit (scoped; configuration.nix via temporary index), push branch, PR `Closes #10`

## Verification log

- delta 0.19.2 strips `ESC]1337` even with `--raw` (2 → 0 in fixture); lazygit/gocui drops unknown OSC
  (`stateOSCSkipUnknown`), so images are written by the pager, not delta.
- pty pipeline: image-only → 2 escapes + removed/added labels; mixed diff order = delta header → labels →
  escapes → delta t.txt; text-only diff fully delta-styled, no escapes.
- Upstream references: dandavison/delta#1399 (open), jesseduffield/lazygit#3776 (won't fix inline).
