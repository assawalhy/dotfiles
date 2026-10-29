# Global agent instructions

Read `~/.agents/AGENTS.md` before your first tool call in a session. It is the single source
for the toolchain, build and test etiquette, writing style, the comment budget, git and planning
rules.

This file exists because OpenCode loads instructions by directory scope and does not expand the
`@~/.agents/AGENTS.md` import the harness files use. `~/AGENTS.md` is an ancestor of every
workspace under home, so it loads on its own. The import does not. Do not delete it as a
duplicate of the harness file: it is the only copy OpenCode reads without being asked.

## Validation scope

For validation changes, run only the tests affected by the change. Do not run the entire test
suite unless the user explicitly asks for full-suite verification or the change spans the whole
project.
