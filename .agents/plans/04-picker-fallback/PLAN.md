# Plan: typed picker fallback when fzf is absent

## Goal
On a fresh machine without fzf, the interactive pickers must accept typed,
comma- or space-separated selections (numbers and ranges), and a picker that
cannot prompt must fail loudly instead of silently selecting nothing.

## Approach
- `common/bin/setup-os`: keep fzf-first `choose()`; make `menu_fallback` accept
  comma/space/ranges + `n`; error with guidance when no terminal is available.
- `link-files.bash`: accept commas in `expand_selection`; update prompt/help.
- `setup/agent-skills.sh`: accept commas; update prompt.
- Tests: comma case in the link-files picker; a new `tests/select.bats` unit
  test for the `expand_selection` in setup-os and agent-skills.

## Decisions
- fzf stays the picker whenever installed (fzf gate unchanged; user's call).
- One parser shape in all three scripts: `tr ',' ' '` then the existing
  space/range loop. Rejected: whiptail/dialog (new fresh-box dependency).
- setup-os keeps `empty = none` (safe for installs); link-files/agent-skills
  keep `empty = all`. `n`/`none` works in all three.
- No-tty picker -> exit 1 with `--all` / `--priority` / `--group` guidance.
  Rejected: scripted stdin selection (flags already cover non-interactive).

## Milestones
1. the three selection parsers + setup-os no-tty guard
2. tests + docs
3. verification

## Risks
- setup-os `menu_fallback` exit inside a pipeline subshell would not propagate;
  the tty guard lives in `main` before `choose`, not inside the fallback.
- Extraction-based unit tests depend on `expand_selection` staying a top-level
  function ending with `}` at column 0.
