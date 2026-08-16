# Task 2 — Delete lua/plugins/autoformat.lua (kickstart leftover)

Date: 2026-08-15
Plan: .omo/plans/nvim-config-cleanup-and-java.md (todo 2)

## What was done

1. Deleted `common/.config/nvim/lua/plugins/autoformat.lua` (74-line kickstart.nvim BufWritePre formatter that double-formats with conform's format_on_save).
2. Grepped the whole nvim dir for `autoformat` / `KickstartFormat` / `tsserver` — zero stragglers found (no references in init.lua or any other plugin file).
3. Removed the stale per-file symlink `~/.config/nvim/lua/plugins/autoformat.lua` (pointed at the deleted repo file; caused `Failed to load plugins.autoformat` on boot).
4. Verified headless boot is clean.

## Commands + outputs

### 1. Delete the file

```
$ rm common/.config/nvim/lua/plugins/autoformat.lua && test ! -f common/.config/nvim/lua/plugins/autoformat.lua && echo "FILE DELETED OK"
FILE DELETED OK
```

### 2. Grep for stragglers (acceptance criterion 2)

```
$ grep -rn 'autoformat\|KickstartFormat' common/.config/nvim
(no matches — exit 1)
```

Also checked `tsserver` (the kickstart formatter's special-case client name):

```
$ grep -rn 'tsserver' common/.config/nvim
(no matches — exit 1)
```

### 3. Stale symlink cleanup (live config)

```
$ ls -la ~/.config/nvim/lua/plugins/autoformat.lua
/home/ms/.config/nvim/lua/plugins/autoformat.lua -> /home/ms/myp/dotfiles/common/.config/nvim/lua/plugins/autoformat.lua  68B
$ rm ~/.config/nvim/lua/plugins/autoformat.lua
STALE SYMLINK REMOVED
```

Before removal, boot showed the lazy loader error (exit still 0):
```
Error in /home/ms/.config/nvim/init.lua:
Failed to load `plugins.autoformat`:
cannot open /home/ms/.config/nvim/lua/plugins/autoformat.lua: No such file or directory
```

### 4. Headless boot verification (QA happy path)

```
$ nvim --headless -c 'qa' 2>&1
(no output)
EXIT: 0
```

## Acceptance criteria

| Criterion | Result |
|---|---|
| `test ! -f common/.config/nvim/lua/plugins/autoformat.lua` | PASS |
| `grep -rn 'autoformat\|KickstartFormat' common/.config/nvim` exits 1 | PASS (no matches) |
| `nvim --headless -c 'qa'` exits 0 | PASS (clean, no messages) |

## Notes

- No replacement formatter added — conform (T4) already handles format_on_save with lsp_fallback.
- No other plugin files modified.
- Failure run captured: the stale symlink boot error above; fixed by removing the symlink, re-ran boot clean.