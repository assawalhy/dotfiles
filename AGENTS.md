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

## Commit Conventions

Prefix with a lowercase scope: `nvim:`, `setup:`, `shell:`, `docs:`, `test:`

Examples:
- `nvim: replace codeium with supermaven-nvim`
- `setup: remove cht.sh, add mise and herdr steps`
- `shell: add mise activation`
