# Agents

## Repo Assumptions

- This repo is **always a git repo**. `link-files.bash` relies on `git
  check-ignore --no-index` in `refresh_scan`; on a non-git checkout it skips
  every capture candidate and audit reports zero `[unlinked]`. Do not add
  non-git handling — the path is dead in practice and documented as a known
  issue in `tests/link-known-issues.bats`.

## Testing

`link-files.bash` is covered by a bats suite in `tests/`. Run it with:

```bash
bats tests/link-files.bats          # main suite (expected: 112 ok, 0 not ok)
bats tests/link-known-issues.bats   # known-bug encodings (expected: 3 ok, 1 not ok — #4)
bats tests/select.bats              # typed multi-select parser (setup-os, agent-skills)
```

- **`tests/link-files.bats`** — locks in current behavior: link-, classify-,
  overlay-, context-, ignore-, refresh-, audit-, picker-, cli-, fix-, guard-
  prefixed tests (filter with `bats --filter '^audit-'`). Tests only the
  committed script; the OS is stubbed (`setup()` stubs `uname` to Linux,
  overlay tests override with `stub_uname Darwin`).
- **`tests/select.bats`** — no terminal/fixtures: `eval`s the real
  `expand_selection` extracted from `common/bin/setup-os` and
  `setup/agent-skills.sh` and checks comma/space/ranges plus `a`/`n`/empty.
  Keep `expand_selection` top-level with a bare `}` at column 0 or the awk
  extractor breaks.
- **`tests/helpers.bash`** — `fixture_new <name> [git]` builds a throwaway
  fixture repo + fake `$HOME` under `$BATS_TEST_TMPDIR` (auto-cleaned); the
  real `$HOME` is never touched. Each fixture copies the real script, so
  `link-files.bash`'s `$REPO`-from-own-location resolves to the fixture.
  `FIX_REPO`/`FIX_HOME` are resolved via `cd -P` to match the script's
  resolution on macOS (`/var`→`/private/var`); keep that in mind when adding
  helpers. The helpers run under the bats runner's modern bash; the *script*
  under test must stay bash 3.2 compatible.
- Session context for neglect filtering via `run_link_sess <wayland|x11|headless>`.
- The `fix-` tests cover the seventh state, the capture direction (`--refresh`
  inside `--fix`): into `common` or the OS overlay, `--dry-run` moves nothing,
  ignored/gitignored candidates never captured, a pattern narrows the scan to
  the dirs it matches, `--no-capture` stays link-only, a second `--fix` is a
  no-op, and the `?` other-overlay candidate is reported but never captured.
- The audit corner-case tests are the regression net: foreign/relative
  symlinks → `[conflict]`, OS-mismatch stales, prefix collisions, dir-prefix
  and `./` ignore entries, pattern narrowing, Xwayland session detection,
  hard-link/cross-overlay `[relink]`, dir-at-file-path `[conflict]`, an
  ignored+neglected link reported once, and the `--refresh`/`--audit`/`--fix`
  skip rules.

## Known Issues

Real bugs encoded as tests in `tests/link-known-issues.bats`. Each
is a standalone work item: fix `link-files.bash`, the test turns green. The
file documents the failure, the desired behavior, and where in the code
the bug lives. Fixed entries stay in the file as the regression net.

**Fixed** (test green):

1. ~~**`--audit --refresh` writes.**~~ `parse_args` now rejects the pair:
   `--audit` is read-only by contract, so the combination is contradictory
   rather than "audit wins".
2. ~~**Leading whitespace in `link-context.txt` breaks neglect.**~~
   `read_contexts` trims every line *before* the comment/blank/malformed
   filters, so an indented `x11: .Xmodmap` keeps its own context.
3. ~~**Ignored + neglected links are double-reported.**~~ The `x [neglected]`
   report is skipped for rels already reported as `i [ignored]`
   (`already_ignored`); the ignore list is explicit config, so it wins.

**Open:**

4. **Non-git repo silently reports zero `[unlinked]`.** (Deliberately
   unfixed — see Repo Assumptions.) In `refresh_scan`, a `git check-ignore`
   exit status other than 0/1 (i.e. not a repository) empties the kept
   candidate list. Kept as documentation only.

## Issue Tracking

```bash
# List open issues
gh issue list --repo assawalhy/dotfiles

# View issue details
gh issue view <N> --repo assawalhy/dotfiles

# View with comments
gh issue view <N> --repo assawalhy/dotfiles --comments

# Create a new issue
gh issue create --repo assawalhy/dotfiles --title "Title" --body "Description"

# Close an issue (via commit message: Closes #<N>)
git commit -m "fix: description\n\nCloses #<N>"
```

## GitHub Project Board

> Requires `read:project` and `project` scopes. Run once:
> ```bash
> gh auth refresh -s read:project project
> ```

```bash
# List projects
gh project list --owner assawalhy

# List items in a project
gh project item-list <PROJECT_NUMBER> --owner assawalhy

# Add an issue to the project
gh project item-add <PROJECT_NUMBER> --owner assawalhy --url https://github.com/assawalhy/dotfiles/issues/<N>

# Update item status (Todo / In Progress / Done)
# First get the field ID and option IDs:
gh api graphql -f query='
{ organization(login: "assawalhy") {
    projectV2(number: <PROJECT_NUMBER>) {
      fields(first: 20) { nodes { ... on ProjectV2SingleSelectField { id name options { id name } } } }
    }
  }
}'
# Then update:
gh project item-edit --project-id <PROJECT_ID> --id <ITEM_ID> --field-id <FIELD_ID> --single-select-option-id <OPTION_ID>
```

## Nvim Conventions

When editing the nvim config under `common/.config/nvim/`, every key binding —
whether `vim.keymap.set`, a lazy.nvim `keys` entry, or a plugin `on_attach`
mapping — **must** include a `desc` field. This keeps `which-key`, `:map`, and
`<leader>` discoverable. Existing bindings without `desc` should be expanded
rather than left bare.

## Workflow

1. Pick an issue from the board (status: Todo)
2. Create a branch: `git checkout -b fix/issue-<N>-<short-description>`
3. Implement changes
4. Commit with `Closes #<N>` in the message
5. Comment on the issue with a summary
6. Update project status to "Done"

## Setup Package System

`setup-os` (symlinked to `~/bin/setup-os`) installs everything from `setup/packages.list`.

- **Managers**: `brew cask pacman aur apt dnf zypper cargo go npm pip`
  - On **NixOS** the system-scope managers are skipped (`PM=nixos`, detected
    via `/etc/NIXOS`): system packages are declared in `configuration.nix`
    (mapped from `setup/packages.list`), and setup-os only runs user-scope
    installs — `setup/steps` and the `cargo/go/npm/pip` groups. `npm -g` is
    redirected to a writable `~/.local` prefix (nixpkgs' npm prefix is
    read-only) and no sudo is invoked.
- **Sections** `[cargo]`, `[go]`, `[npm]`, `[pip]` install via `cargo install`,
  `go install`, `npm install -g`, `pipx install` instead of a native package:
  - `[go]` entries: `id  go:<module-path>  check:<bin>  pN`
  - `[npm]` entries: `id  npm:<package>  check:<bin>  pN`
- **`mgr:-`** marks a package unavailable for that manager (e.g. `apt:-` on
  Debian-like distros when the package isn't in apt repos)
- **`check:<cmd>`** hides the entry when the binary already exists
- **Priority tiers**: `p1` essentials, `p2` dev workstation, `p3` GUI, `p4` occasional
- Non-package installs live in `setup/steps/*.sh`; the go step
  (`setup/steps/05-golang.sh`) auto-runs when `[go]` packages are selected but
  Go is missing
- Step headers: `# desc:` `# os:` `# check:` `# prio:` plus optional
  `# requires:` (space-separated commands; the step is only offered when at
  least one exists — e.g. `02-paru.sh` requires `pacman`).

Coding agents: `opencode`/`claude` install via dedicated steps
(`setup/steps/61-opencode.sh`, `62-claude-code.sh`), `pi` via `[go]`,
`codex`/`kilo` via `[npm]`.

Useful commands:
```bash
setup-os --list                 # what resolves on this machine
setup-os --list --show-installed
setup-os --dry-run --all
setup-os --priority p1 -y
```

## Agent Skills & Shared Context

Two kinds of artifacts, two source-of-truth rules:

- **Installable artifacts** (skills, plugins, MCPs, packages) are recorded in
  `setup/agent-skills.list` and installed fresh by `setup/agent-skills.sh` —
  nothing is copied as a whole config file.
- **Authored context files** (AGENTS.md, CLAUDE.md) are committed in `common/`
  and symlinked by `link-files --fix`. Nothing can regenerate them, so the repo
  is the source.

### Catalog (`setup/agent-skills.list`)

- **`agents-skill`** — clone from a public repo into `~/.agents/skills/`
- **`pi-package`** — pi extension install (`pi install ...`)
- **`plugin`** — clone + run its own installer (currently `awesome-agent`)
- **`agent-tool`** — one entry per utility; `setup/agent-tools.sh` installs *
  into every harness present* (opencode, claude, codex, cursor, pi, kiro, ...).
  Tools: `context7` (MCP docs), `plannotator` (plan/code review CLI + sem
  sidecar + runtimes, via its official installer), `typescript-lsp`, `graphify`
  (knowledge-graph CLI; the PyPI `graphifyy` package's own `graphify install`
  handles the per-harness skill copy), `zvec-grep` (local semantic workspace
  search; npm `@zvec/zvec-grep` + `zg install` writes the per-harness MCP entry).

`setup/agent-skills.sh` modes: `--list` (catalog with installed markers),
`--all` (install every item), `--dry-run`, `--context` (prints how committed
context is wired — the wiring itself is `link-files --fix`). Orca-sourced
skills/configs are intentionally **not** in the catalog.

### Committed context (`common/`)

- `common/.agents/AGENTS.md` — global agent instructions, wired to
  `~/.agents/AGENTS.md`
- `common/.claude/CLAUDE.md` — Claude Code persona + import of the global file,
  wired to `~/.claude/CLAUDE.md`

These are real dotfiles managed by `link-files` like every other file in the
repo. The old `wire_context` in agent-skills.sh was removed: two writers for
one path is how `~/.agents/AGENTS.md` ended up as a 2-line stub.

**The awesome-agent plugin (`assawalhy/awesome-agent`) owns its own files** — the
catalog entry `plugin|awesome-agent` clones the repo and runs its `install.sh`,
which installs the commands, sub-agents (awesome-agent, awesome-worker) and
skills (awesome-plan, ddd, pr-description) into every installed harness itself
(claude, pi prompts, cursor, codex, opencode, kilo, kiro, kimi), tracking them
in `~/.local/share/awesome-agent/registry.txt` and updating with
`bash ~/.local/share/awesome-agent/repo/install.sh update`. Do not mirror or
symlink those files in `common/` — the plugin's writes would fight the links.

Harness-agnostic skills install into `~/.agents/skills/` by git-clone from
their public repos (the catalog's `agents-skill` entries); pi packages and
claude/codex plugins install via their own CLIs; multi-harness tools via
`setup/agent-tools.sh`. `~/.agents/skills/` and `~/.agents/.skill-lock.json`
are script-managed install state, excluded from `link-files` via
`link-ignore.txt` — never commit the installed copies. The `use-railway` skill
is intentionally **not** in this repo — install it from the official
`railwayapp/railway-skills` repo instead.

## Commit Conventions

Prefix with a lowercase scope: `nvim:`, `setup:`, `shell:`, `docs:`, `test:`

Examples:
- `nvim: replace codeium with supermaven-nvim`
- `setup: remove cht.sh, add mise and herdr steps`
- `shell: add mise activation`
