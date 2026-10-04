# TODO — Restore opencode context files and configs

## Baseline

- [x] Record the current live state for later comparison:
      `cp ~/.config/opencode/{opencode.json,cli.json,AGENTS.md}` to `$TMPDIR`,
      and `link-files.bash --audit` totals (currently 7 findings)

## Templates

- [x] `setup/templates/opencode.json` — the live `opencode.json` content:
      `default_agent`, the three `~/MEMORY.md` permission rules, `mcp.zvec_grep`.
      No `$schema` (the published schema is V1-shaped and would flag `compaction`)
- [x] `setup/templates/cli.json` — the live `cli.json` content, keeping its
      existing `$schema: https://opencode.ai/v2/cli.json`
- [x] `python3 -m json.tool` both templates; confirm `opencode.json` carries no
      secrets (it must not — `service.json` is separate)
      → both valid, byte-identical to the live files, no secret-like keys

## Step 68 — seed the configs

- [x] `setup/steps/68-opencode-config.sh` with headers `# desc:`, `# os: any`,
      and a `# check:` that passes when both config files already exist
      → **`requires: jq` dropped**: 68 only copies templates, so it does not
      need jq. `requires: jq` belongs on step 69.
- [x] Resolve each config path with the same precedence `agent-tools.sh` uses
      (`.config/opencode/opencode.jsonc` → `opencode.json` → `.config/opencode.jsonc`
      → `.config/opencode.json`)
      → default target is **`opencode.json`**, not `.jsonc`: seeding a `.jsonc`
      path invites `jq_add_key` to strip its comments
- [x] Create-if-missing from the template; **never** overwrite an existing file
- [x] Degrade with a printed message when a template is missing
- [x] `bash -n setup/steps/68-opencode-config.sh`
- [x] Fresh-HOME test: both files seeded, byte-identical to templates, mode 600,
      re-run is a no-op, an existing file is not clobbered, and
      `XDG_CONFIG_HOME` is honoured for `cli.json` only (per the CLI docs)


## Step 69 — compaction (epic 16)

- [x] `setup/steps/69-opencode-compaction.sh` — `.compaction =
      {auto:true, keep:{tokens:30000}, buffer:65536}` via jq, creating the file
      from the template if step 68 has not run yet
- [x] `# check:` tests the compaction block, so a re-run is a no-op
- [x] `bash -n setup/steps/69-opencode-compaction.sh`
- [x] Verified: works standalone on a bare `HOME` (seeds first), preserves
      `default_agent` / `permissions` / `mcp`, leaves corrupt JSON untouched,
      degrades with exit 0 when `jq` is missing, and the `# check:` header
      returns the right answer in all four states

## packages.list

- [x] Add `jq` at `p1` — nothing above works without it

## agent-tools.sh

- [x] `jq_add_key`: create the file from `{}` when missing instead of returning
      early
- [x] `opencode_cfg`: return the path step 68 seeds instead of failing, so the
      MCP wiring lands on a fresh machine
- [x] Confirm the context7 / plannotator / zvec-grep wiring now lands on a
      fresh machine — verified end-to-end: `agent-tools.sh install context7` on a
      bare `HOME` creates the config, adds `mcp.context7`, and step 68 then tops
      `default_agent` / `permissions` / `mcp.zvec_grep` back up underneath it

## AGENTS.md becomes repo-owned

- [x] Copy the live `~/.config/opencode/AGENTS.md` to
      `common/.config/opencode/AGENTS.md`, byte-for-byte, markers intact
- [x] `git add` it **before** linking, so nothing can be lost
- [x] `link-files.bash --diff` first, then `--fix --force` (scoped with the
      `opencode` filter so nothing else in the repo was touched)
- [x] Confirm `~/.config/opencode/AGENTS.md` is now a symlink into the repo and
      `readlink` resolves — `/home/assawalhy/Projects/dotfiles/common/.config/opencode/AGENTS.md`
- [x] Redundant `AGENTS.md.bak.*` removed after verifying byte-identity

## Ignore the siblings — BEFORE any refresh

- [x] `link-files.bash --audit` and capture every new opencode entry
      → **17 new `[unlinked]` candidates appeared**, confirming the hazard,
      including `service.json`, `agents/`, `command/`, `skills/`, `plugins/`,
      `herdr-opencode/`, `herdr-tui-session.js`, `tui.jsonc`, plus `opencode.json`
      and `cli.json`
- [x] Add `link-ignore.txt` entries for all of them, each annotated with which
      component owns it
- [x] Re-audit and assert **`service.json` never appears** — 0 occurrences
- [x] Audit returned to the **baseline 7 findings** (6 pre-existing stale links
      + `.config/nvim/lua/config/cp.lua`)
- [x] Never ran `--refresh`

## Epic 17 steering (retargeted)

- [x] Add the `## Browser automation` section to
      **`common/.config/opencode/AGENTS.md`** (the repo file), not the home file
- [x] Assert it does not collide with the `ZVEC_GREP_START/END` markers or the
      existing section headers — 5 headers, no duplicates, both markers intact
- [x] Also point the "Login walls and bot checks" section at `playwright-cli`,
      since it already told me to sign in "in the browser"


## Verify

- [x] Fresh-HOME smoke test — `setup-os` steps only: both JSONs seeded, compaction
      applied, `mcp` ends up `context7,zvec_grep`, `permissions` = 3,
      `cli.json` intact; re-running changes no bytes
- [x] Fresh-HOME `link-files --fix` closes the other half — `AGENTS.md` symlinked
      with the browser section present, and `opencode.json` correctly *not*
      linked
- [x] `bats tests/link-files.bats` — **99 ok, 0 not ok**, matching the documented
      baseline
- [x] `bats tests/select.bats` — 5 ok, 0 not ok
- [x] `bats tests/link-known-issues.bats` — 4 not ok, unchanged, still the
      documented encoding of real bugs
- [x] `opencode api get /api/config` reports the compaction block; the running
      service picked it up with **no restart**
- [x] `zg install --target opencode --yes` against the linked `AGENTS.md` —
      **symlink survived**, md5 unchanged, zvec markers intact, `opencode.json`
      untouched. It writes in place rather than `mv`-ing over the link.
- [x] `git ls-files common/.config/opencode/` tracks exactly one file:
      `AGENTS.md`. No `service.json`, no JSON configs.
- [x] `git status` — `AGENTS.md` staged, **nothing committed**

## Notes

- The live `~/.config/opencode/opencode.json` now carries `.compaction`
  (epic 16, applied here). Step 69 was only exercised against throwaway `HOME`s
  until the final pass — a green test suite says nothing about whether the step
  was actually run for real.
- `--audit` holds at the 7 pre-existing findings: 6 stale links and
  `.config/nvim/lua/config/cp.lua`, all predating this work.
- `~/.config/opencode/AGENTS.md.bak.*` was created by `link-files --force` and
  deleted after byte-identity was confirmed against the committed copy.
- Step 68's semantics grew during implementation from *create-if-missing* to
  **merge the template underneath**: `jq -s '.[0] * .[1]'` fills in only absent
  keys. Create-only would silently lose the committed defaults if any tool
  created a bare `{}` config first. A guard skips the merge entirely when every
  template key is already present, so a healthy file is never reformatted.
