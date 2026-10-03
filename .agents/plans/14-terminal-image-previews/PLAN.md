# 14 — Terminal image previews (issue #10)

## Goal

Images are visible where they are reviewed: `git diff`/`show`/`log -p`, lazygit,
and nvim. In nvim, non-text files (video, PDF, archives, binaries) prompt to open
with `xdg-open` instead of loading a binary buffer.

## Approach

- Rendering uses the iTerm2 inline-image protocol (`OSC 1337`) start to finish;
  WezTerm (current terminal) supports it natively. Kitty graphics is default-on
  in WezTerm since 2023, so no WezTerm config change.
- git CLI: a global attributes file marks raster images `diff=img`;
  `git-img-textconv` emits the inline-image escape for each image blob
  (downscaled via ImageMagick when present, 25 MB cap). `core.pager` becomes
  `git-img-pager`: text runs pipe through `delta --paging=never` as today, image
  escape lines are written straight to the terminal. delta drops OSC 1337 by
  design (upstream #1399), so it must never see image lines.
- lazygit: inline images inside panes are impossible (gocui discards unknown OSC;
  upstream #3776). A files-context custom command on `I` runs `git-img-preview`
  with `output: terminal` — lazygit suspends and the diff renders in the real
  terminal, images included.
- nvim: `snacks.nvim` image module only. Opening an image file shows a float
  preview (WezTerm lacks kitty unicode placeholders, so snacks falls back to
  floats); `<leader>ip` previews the image path under the cursor.
  New `config/nontext.lua`: curated extension list via `BufReadCmd` +
  `BufReadPost` NUL-sniff fallback, `vim.ui.select` prompt → `vim.ui.open`
  (xdg-open). "Keep in Neovim" reloads normally by temporarily removing the
  autocmd (`BufReadPre` cannot change the buffer — E201, verified).
- Package: `imagemagick` (snacks conversion for non-PNG; textconv downscale) in
  `setup/packages.list` + `configuration.nix`, then rebuild.

## Decisions

| # | Decision | Why | Rejected |
|---|----------|-----|----------|
| D1 | Pager wrapper, delta unchanged | delta 0.19.2 strips OSC 1337 even with `--raw` (verified); patching would also need to skip word-diff/wrap for megabyte base64 lines | nixpkgs delta overlay patch; upstream (open since 2023) |
| D2 | lazygit gets a terminal-takeover preview key | gocui drops unknown OSC before draw; upstream won't add it | inline pane (impossible) |
| D3 | snacks.image over image.nvim | snacks lists WezTerm and float fallback explicitly; image.nvim calls WezTerm unsupported | image.nvim |
| D4 | `BufReadCmd` ext list + NUL sniff | multi-GB video never loads; unknown binaries still caught | `BufReadPre` (E201); filetype detection only |
| D5 | `I` in lazygit files context | `i` (ignore) and `o` (xdg-open) taken | alias/`o` only |
| D6 | Textconv output caps at 25 MB, resized to ≤1000px | keeps diffs light; magick is installed anyway for nvim | raw base64 always |

## Milestones

1. Scripts + git config; CLI images verified under a pty.
2. lazygit command + script; pty check, user visual check.
3. nvim snacks module + nontext module + README; headless verification.
4. imagemagick in packages.list/configuration.nix + rebuild.
5. link-files + bats, user visual checks, commit/PR `Closes #10`.

## Risks

- WezTerm's kitty graphics is "limited"; if snacks floats misbehave, fall back to
  xdg-open for images or image.nvim.
- Wrapper adds a process in front of paged diffs; text-only path streams through
  one delta child (≤8 MiB buffered before switching to stream mode).
- Global textconv makes big image diffs heavier — capped/downsized above.
- `configuration.nix` carries epic-13 uncommitted hunks; commit ours scoped with
  the temporary-index trick used in earlier epics.
- master is 2 commits ahead of origin; the PR includes them unless master is
  pushed first.
