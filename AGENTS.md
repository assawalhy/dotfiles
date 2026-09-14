# Agents

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

## Commit Conventions

Prefix with a lowercase scope: `nvim:`, `setup:`, `shell:`, `docs:`, `test:`

Examples:
- `nvim: replace codeium with supermaven-nvim`
- `setup: remove cht.sh, add mise and herdr steps`
- `shell: add mise activation`
