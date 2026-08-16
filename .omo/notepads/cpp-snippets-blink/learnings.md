# cpp-snippets-blink — Learnings

## Task
Make `~/myp/problem-solving/cpp.snippets` work with blink.cmp in the nvim config.

## Key facts (verified 2026-08-16)
- The user's file is `~/myp/problem-solving/cpp.snippets` (plural, `.snippets`), NOT `cpp.snippet`. It is a **snipmate/UltiSnips-format** file: `snippet <trigger>` + indented body, `#` comments, `${1:...}`/`${0}` tabstops. 55 C++ competitive-programming snippets (temp, tempt, dbg, arr, tree, code_* algorithms).
- blink.cmp config: `common/.config/nvim/lua/plugins/blink.lua` — `sources.default = { 'lsp', 'path', 'buffer', 'snippets' }`. The `snippets` source is enabled but has NO engine configured (no LuaSnip, no `snippets` preset).
- **blink.cmp natively supports VSCode-style JSON snippets**, auto-loading from `~/.config/nvim/snippets/` (per official docs). No LuaSnip needed for VSCode-format snippets.
- Existing `common/.config/nvim/snippets/` contains only `typescriptreact.snippets` (snipmate format, orphaned — not referenced anywhere).

## Approach (chosen)
Convert `cpp.snippets` (snipmate) → VSCode JSON (`cpp.json`), place in `common/.config/nvim/snippets/`, add `package.json` registering it for the `cpp` language. This avoids LuaSnip entirely.

## Constraints / conflicts
- **PARALLEL SESSION ACTIVE**: `nvim-config-cleanup-and-java` plan is mid-flight. Its todo 6 ("Migrate completion to blink.cmp") EXPLICITLY forbids adding LuaSnip ("do not add a LuaSnip dependency", "keep friendly-snippets").
- Do NOT edit `blink.lua` (owned by parallel session, untracked/being created by it).
- Do NOT touch `common/.config/nvim/lua/plugins/cmp.lua` (deleted by parallel session).
- Only touch `common/.config/nvim/snippets/` (cpp.json + package.json). This dir is NOT in the parallel session's scope.
- The `snippets/` dir is linked into `~/.config/nvim/snippets/` via link-files.bash (per-file symlinks). New files there are NOT live until `./link-files.bash` runs — but that's the parallel session's todo 14 concern; for now just create the files in the repo.

## Snipmate → VSCode JSON conversion rules
- `snippet <trigger>` → JSON key = trigger, `"prefix": "<trigger>"`.
- Indented body lines → array of strings in `"body"`, strip the leading 4-space indent.
- `${1:...}` / `${0}` tabstops are already VSCode-compatible — keep as-is.
- `#` comment lines → drop.
- `endsnippet` / blank separators → drop.
