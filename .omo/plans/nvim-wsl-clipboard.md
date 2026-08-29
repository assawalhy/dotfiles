# Plan: WSL nvim clipboard must land on the Windows clipboard

## Problem

On WSL, text copied from nvim (`;y` -> `"+y`) does not appear in the Windows
clipboard, while terminal-level `xsel` works fine. Pre-existing issue; not
caused by recent changes.

## Diagnosis (evidence gathered)

| Fact | Value |
|---|---|
| `DISPLAY` | `172.26.96.1:0` (VcXsrv on Windows host, set by `linux/.config/shell/os.sh`) |
| `WAYLAND_DISPLAY` | `wayland-0` (WSLg native) |
| `$XDG_RUNTIME_DIR/wayland-0` | symlink -> `/mnt/wslg/runtime-dir/wayland-0` (guard already added to os.sh) |
| Tools | `wl-copy`, `wl-paste`, `xclip`, `xsel` all installed |
| Roundtrip probe | headless `setreg('+','CLIPPROBE9')` was readable by **wl-paste AND xclip AND xsel** against VcXsrv -> pipeline works in a fresh env |

Conclusion: two compounding causes.

1. **Stale environments**: shells/nvim opened before the os.sh socket-guard
   existed have `wl-copy` failing silently (socket missing where
   `$WAYLAND_DISPLAY` points). Fix = restart shell + nvim (no code change).
2. **Provider split-brain**: nothing sets `vim.g.clipboard`, so nvim probes
   providers itself and can pick a different backend than `bin/clip` would.
   The README promises "tmux and nvim both go through clip" -- nvim currently
   violates that contract. Pinning nvim's provider to `clip` removes the
   nondeterminism permanently.

## Change (single file)

`common/.config/nvim/lua/config/keymaps.lua`

Insert directly after the `CopyBuffer()` function body (after the line
`end` that closes it, before the `;y` keymap):

```lua
-- Route the +/* registers through clip as well: left alone, nvim probes
-- providers itself and can settle on a different backend than clip picks,
-- leaving the two paths out of sync.
if vim.fn.executable 'clip' == 1 then
  vim.g.clipboard = {
    name = 'clip',
    copy = { ['+'] = 'clip', ['*'] = 'clip' },
    paste = { ['+'] = 'clip -o', ['*'] = 'clip -o' },
  }
end
```

Guard keeps behavior unchanged on machines without `~/bin/clip`
(nvim falls back to its normal probing).

## Verification

```sh
# 1. provider wired + copy direction routes through clip
nvim --headless "+lua print('PROVIDER='..vim.g.clipboard.name); vim.fn.setreg('+','NVIMCLIP7')" +qa
clip -o            # expect: NVIMCLIP7

# 2. paste direction roundtrip
printf 'PASTE9' | clip && clip -o   # expect: PASTE9
```

## User steps after apply

Restart the WSL shell (`exec zsh` / reopen terminal) so os.sh runs the
wayland-0 guard, then restart nvim. Use `;y` (or `;wc`) to copy.

## Out of scope / optional follow-up

- Uncommenting `vim.o.clipboard = 'unnamedplus'` (options.lua line 12) if the
  user wants *every* yank mirrored to the OS clipboard, not just `;y`.
