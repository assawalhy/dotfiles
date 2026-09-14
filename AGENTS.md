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
bats tests/link-files.bats          # main suite (expected: 97 ok, 0 not ok)
bats tests/link-known-issues.bats   # known-bug encodings (expected: all fail)
```

- **`tests/link-files.bats`** — locks in current behavior: link-, classify-,
  overlay-, context-, ignore-, refresh-, audit-, picker-, cli-, guard-
  prefixed tests (filter with `bats --filter '^audit-'`). Tests only the
  committed script; the OS is stubbed (`setup()` stubs `uname` to Linux,
  overlay tests override with `stub_uname Darwin`).
- **`tests/helpers.bash`** — `fixture_new <name> [git]` builds a throwaway
  fixture repo + fake `$HOME` under `$BATS_TEST_TMPDIR` (auto-cleaned); the
  real `$HOME` is never touched. Each fixture copies the real script, so
  `link-files.bash`'s `$REPO`-from-own-location resolves to the fixture.
  `FIX_REPO`/`FIX_HOME` are resolved via `cd -P` to match the script's
  resolution on macOS (`/var`→`/private/var`); keep that in mind when adding
  helpers. The helpers run under the bats runner's modern bash; the *script*
  under test must stay bash 3.2 compatible.
- Session context for neglect filtering via `run_link_sess <wayland|x11|headless>`.
- The audit corner-case tests are the regression net: foreign/relative
  symlinks → `[conflict]`, OS-mismatch stales, prefix collisions, dir-prefix
  and `./` ignore entries, pattern narrowing, Xwayland session detection,
  hard-link/cross-overlay `[relink]`, dir-at-file-path `[conflict]`, and the
  `--refresh`/`--audit` skip rules.

## Known Issues

Real bugs encoded as failing tests in `tests/link-known-issues.bats`. Each
is a standalone work item: fix `link-files.bash`, the test turns green. The
file documents the current failure, desired behavior, and where in the code
the bug lives.

1. **`--audit --refresh` writes.** `parse_args` only guards `--fix`; `main`
   checks `is_refresh` before `is_audit`, so `--audit --refresh --yes`
   silently moves a home file into the repo. Desired: `--audit` is read-only
   — never write regardless of other flags.
2. **Leading whitespace in `link-context.txt` breaks neglect.** A
   `"  x11: .Xmodmap"` line parses the context as `"  x11"` (whitespace
   kept), so the file is neglected on every session including its own x11.
   Desired: trim leading whitespace on context lines.
3. **Ignored + neglected links are double-reported.** A link both in
   `link-ignore.txt` and neglected for the session is reported as both
   `i [ignored]` and `x [neglected]`. Desired: report once; `i` wins (the
   ignore list is explicit config).
4. **Non-git repo silently reports zero `[unlinked]`.** (Deliberately
   unfixed — see Repo Assumptions.) `refresh_scan`'s git error path skips
   every capture candidate. Kept as documentation only.

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

## Commit Conventions

Prefix with a lowercase scope: `nvim:`, `setup:`, `shell:`, `docs:`, `test:`

Examples:
- `nvim: replace codeium with supermaven-nvim`
- `setup: remove cht.sh, add mise and herdr steps`
- `shell: add mise activation`
