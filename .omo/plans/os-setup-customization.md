# os-setup-customization - Work Plan

## TL;DR (For humans)

**What you get:** your setup script can now install programs by tier. The `p1`
tier has the essentials: git, zsh, tmux, fzf, bat, and more. It also has the
opencode and Claude Code AI agents. You can install them on a new machine with
one command. The `p2` and `p3` tiers give a fuller workstation. The linker has
an interactive file picker. You can type to filter. You can press Ctrl-A to
select all matches. Your selection stays when you clear the query. A numbered
fallback menu is available. The linker does not need Node.js any more. It runs
on a fresh unix system.

**Why this approach:** the tier labels live in the package list that you
already edit. So the priorities are data, not code. The agents install with the
official installers of their vendors. There is no package-manager hack and no
sudo. The interactive picker is the UX you proposed: filter, Ctrl-A, and a
selection that stays.

**What it will NOT do:** it does not add new package managers. It does not
change your dotfiles. It does not change what gets linked by default. It does
not change the conflict rules or the ignore rules. It does not break stock
macOS bash 3.2. The agents are installed. Your setup (shell, tmux, editor
configs) is untouched.

**Effort:** Medium
**Risk:** Medium - two shell scripts get large changes (the setup resolver and
the linker lister). A regression there could break current install or link
runs. A before/after behavior diff guards both.
**Decisions to check:** (1) the tier assignments p1..p4 in `packages.list`
(the agents are on p1); (2) `--priority` selects automatically and does not
show the picker, the same as `--all`; (3) the linker picker selects everything
when fzf is 0.48 or more, otherwise it starts empty (press Ctrl-A).

Your next move: approve this plan, or ask for changes. Then say `$start-work`.
Full execution detail follows below.

---

> TL;DR (machine): Medium effort, Medium risk - 9 todos / 5 waves / 9 commits:
> p1-p4 labels in packages.list + `--priority` auto-select in setup-os + rustup
> auto-promote, 2 new native-installer agent steps (opencode, claude-code),
> bash lister replacing list-files.mjs (no node), interactive picker with
> Ctrl-A/Ctrl-D + fallback menu in link-files.bash, README updates.

## Scope
### Must have
- `setup/packages.list`: every package line has a `pN` tier token (p1..p4).
  The header comment documents the format. Unlabeled defaults to p4.
- `setup-os`: the `--priority p1[,p2]` flag restricts the menu to a tier.
  It also selects the tier automatically. It skips the picker. The `-y` flag
  makes it fully scriptable. The `--list` output has a PRIORITY column.
  The picker labels show `[p1]`. Steps may carry `# prio:`. Rustup runs
  automatically before the cargo batch when cargo is missing. The steps-last
  loop does not run rustup twice. setup-os stays compatible with bash 3.2.
- Two new steps: `setup/steps/61-opencode.sh` and `62-claude-code.sh`.
  They use native installers and `# prio: p1`. All 14 current steps get a
  `# prio:` header.
- `link-files.bash`: an interactive picker (fzf --multi) over linkable files.
  It shows `[group]` labels. `CTRL-A` selects all matches. The selection stays
  across query clears. `CTRL-D` deselects all. TAB toggles. A numbered
  fallback menu is available (empty=all, `n`=none, `a`=all, ranges).
  Pattern, `--dry-run` and `--yes` invocations keep current behavior.
  link-files.bash stays compatible with bash 3.2.
- `list-files.mjs` is deleted. The lister is pure bash and POSIX
  find/awk/sort. Linking works on fresh unix systems with no node.
- README documents all of the above.
### Must not do (safety rules, scope boundaries)
- Do not add new package-manager types. Do not add npm or pnpm sections.
- Do not change `pm_install`.
- Do not change the install order of steps. The only exception is the rustup
  promote.
- Do not change the `link-ignore.txt` semantics.
- Do not change the dotfiles themselves (`common/`, `linux/`, `macos/`).
- Do not change what gets linked by default. Do not change the overlay-wins
  rule.
- Do not use `sudo` in the new agent steps. Do not add a unit-test framework.
- Do not break stock macOS /bin/bash 3.2. Do not use `<<<`, `mapfile`,
  `declare -A`, `${v,,}`, globstar, `sort -V`, or `find -mindepth`.
- Do not run a real install (`setup-os` without `--dry-run`).
- Do not touch the real `$HOME` during QA. Use test HOMEs under
  /tmp/opencode.

## Verification
> Zero human intervention - the agent does all verification.
- Test decision: tests-after, none (the repo has no test infra).
- QA vehicles:
  - `bash -n`
  - `./setup-os --list` and `--dry-run --priority`
  - non-interactive fallback-menu runs against test `$HOME`s with stdin from
    a pipe
  - a failing node stub proves the lister needs no node
  - a guarded cargo-dir strip proves the rustup path
  - source `link-files.bash` and run `fzf_ge` to check the version
  - tmux-driven real-keypress picker QA
  - a sorted-relpath-set diff shows the lister rewrite has the same behavior
- Baseline capture: `/tmp/opencode/link-before.txt` is taken at the START of
  todo 7, before any edit to `link-files.bash`.
- Evidence: `.omo/evidence/task-<N>-os-setup-customization.txt` for every
  todo (commands + outputs). Final wave evidence is in the same dir.
- Safety rules: QA never runs real installs. QA never links into the real
  `$HOME`. Use test HOMEs under `/tmp/opencode/`.

## Execution order
### Parallel waves
- Wave 1 (parallel, files that do not overlap): T1 packages.list · T5 step
  prio headers · T6 agent steps · T7 bash lister (baseline captured first).
- Wave 2 (parallel, files that do not overlap): T2 setup-os resolver · T8
  link-files picker.
- Wave 3: T3 setup-os `--priority` (same file as T2, sequential).
- Wave 4: T4 rustup promote (same file as T3, sequential).
- Wave 5: T9 README (last, after all behavior is final).

### Dependency matrix
| Todo | Depends on | Blocks | Can parallelize with |
| --- | --- | --- | --- |
| 1 packages.list pN | — | 2 | 5, 6, 7 |
| 2 setup-os resolver prio | 1 | 3, 4 | 8 |
| 3 setup-os --priority | 2 | 4 | — (same file as 2, sequential) |
| 4 rustup promote | 3 | — | — (same file as 3, sequential) |
| 5 step # prio: headers | — | — | 1, 6, 7 |
| 6 agent steps | — | — | 1, 5, 7 |
| 7 bash lister | — | 8 | 1, 5, 6 |
| 8 interactive picker | 7 | 9 | 2 |
| 9 README | 8 | — | — |
## Todos
> Implementation and Test = ONE todo. Never separate them.
<!-- APPEND TASK BATCHES BELOW THIS LINE WITH edit/apply_patch - never rewrite the headers above. -->

- [x] 1. `setup/packages.list`: add a `pN` priority token to every package line
  What to do / Must NOT do: add the tier token from the table below to each
  of the 51 entries. Keep every current `mgr:name` and `!os` token. Keep the
  `[section]` headers exactly as written. The `pN` token is the last
  whitespace token of the line. It goes BEFORE any `# comment` at the end of
  the line. The resolver removes `#...` first
  (`sub(/[[:space:]]*#.*$/, "")` at setup-os:175). So a token after a comment
  is invisible. Example: `mousepad p3 !macos   # GTK editor; macOS has TextEdit`
  -> the token `p3` is before the comment. Lines without comments end with
  the token (`git p1`). Update the FORMAT comment block (lines 1-20) to
  document the new token: `pN` = tier (p1 highest), unlabeled defaults to
  p4, `mgr` list stays `brew cask pacman aur apt dnf zypper cargo pip`.
  Tier table (exact): p1 = git zsh tmux fzf bat fd ripgrep eza sd fastmod
  gh · p2 = neovim ranger pipx broot rmem git-fame autopep8 black mdtoc
  docker meld lldb yt-dlp ffmpeg pandoc glow gitui lazygit git-delta · p3 =
  mpv syncthing obsidian typora copyq zathura zathura-pdf-mupdf okular feh
  skim pngpaste mousepad xsel xclip wl-clipboard · p4 = texlive megasync
  noto-fonts-emoji noto-fonts-cjk libxft-bgra luarocks. Do not reorder
  sections. Do not rename ids. Do not change any manager override. Do not
  touch setup/steps/. Known behavior, do not change:
  `common/._بسم_الله_الرحمن_الرحيم` stays listed (the same as today).
  Parallelization: Wave 1 | Blocked by: — | Blocks: 2
  References: `setup/packages.list` (whole file, 85 lines; section headers
  at lines 22/38/49/63/68/73/81; FORMAT comment at 1-20; 18 lines carry a
  trailing `#` comment - 32,33,34,35,40,44,45,46,58,59,60,61,64,66,71,76,77,82).
  Acceptance criteria (agent-executable):
  - comment-stripping token check:
    `awk '!/^[#[]/ && NF' setup/packages.list | sed 's/#.*//' | awk '{ f=0; for (i=1;i<=NF;i++) if ($i ~ /^p[1-4]$/) f=1; if (!f) print "NO PRIO: " $0 }'`
    is empty
  - id multiset unchanged:
    `diff <(awk '!/^[#[]/ && NF {print $1}' setup/packages.list | sort) <(git show HEAD:setup/packages.list | awk '!/^[#[]/ && NF {print $1}' | sort)`
    is empty
  - `./setup-os --list` still runs. The old resolver ignores the new token.
    The list shows the same entries as before.
  QA scenarios (tool + invocation): success = the three commands above +
  `./setup-os --list | head`. Failure = show that the check is strict: run
  the first awk over `git show HEAD:setup/packages.list`. It prints NO PRIO
  lines (the pre-change list fails the new check).
  Evidence: `.omo/evidence/task-1-os-setup-customization.txt`
  Commit: Y | `setup: add p1-p4 priority labels to packages.list`

- [x] 2. `setup-os` resolver: emit the priority as the 5th resolved field
  What to do / Must NOT do: in `resolve()` (awk, lines 172-210), reset the
  priority at the start of each record (`id = $1; skip = 0; prio = ""`).
  Then add this capture INSIDE the current token loop, BEFORE the colon
  check `p = index($i, ":"); if (!p) continue` (line 184):
  `if ($i ~ /^p[0-9]+$/) { prio = $i; continue }`. The reset is important.
  awk variables stay across records. Without the reset, a line without a
  token gets the prio of the previous line. That breaks the documented p4
  default. Change every `print group "\t" id ...` to add
  `"\t" (prio ? prio : "p4")`. Do it in both the cargo/pip branch (189-192)
  and the main branch (209). In `resolve_steps()` (214-229), get an optional
  `# prio:` header. Use the same sed pattern as `# desc:`/`# os:`/`# check:`.
  Emit `step \t <desc> \t step \t <path> \t <prio>` (empty when absent).
  Update the `--list` printer (333-337) to
  `printf '%-10s %-22s %-6s %-8s %s\n' GROUP ID PRIORITY MANAGER PACKAGE`
  with fields `$1 $2 $5 $3 $4`. Do not change fields 1-4 of any resolve
  output. Do not change the picker. Do not change pm_install.
  Parallelization: Wave 2 | Blocked by: 1 | Blocks: 3, 4
  References: `setup-os` lines 172-210 (resolvers), 214-229 (resolve_steps),
  333-337 (--list).
  Acceptance criteria:
  - `./setup-os --list` header shows PRIORITY
  - `./setup-os --list | awk '$1=="terminal" && $2=="fzf"'` prints a row
    whose 3rd column is `p1`
  - `./setup-os --list | awk '$1=="gui" && $2=="obsidian"'` shows `p3`
  - `./setup-os --list | awk '$1=="gui" && $2=="okular"'` shows `p3`
    (okular has a trailing comment. This shows comment-line resolution.)
  - step rows (after todo 5) show the prio in column 3.
  QA scenarios: success = the awk checks above. Failure = default-p4 proof:
  edit one line in `setup/packages.list` to remove its token. Run
  `./setup-os --list | grep '^terminal.*git '`. Check that the row shows
  `p4`. Then run `git checkout -- setup/packages.list`.
  Evidence: `.omo/evidence/task-2-os-setup-customization.txt`
  Commit: Y | `setup-os: resolve and display package priorities`

- [x] 3. `setup-os`: add `--priority` tier auto-selection
  What to do / Must NOT do: CLI parse (57-73): `--priority` takes one arg.
  You can repeat the flag. Split the value on commas. Check each value
  against `^p[0-9]+$`, else `die "invalid priority \"$1\""`. Add each value
  to `prios`. After the `--group` filter block (328-331) add: when `prios`
  is non-empty, filter TMP to rows whose 5th field matches `^(p1|p2|...)$`.
  Add `[ -s "$TMP" ] || die "no entries match priority ..."`. Set
  `want_all=1` whenever `prios` is non-empty. This selects automatically and
  skips the picker. It works like `--all` limited to the tier. It has
  priority over `--all`. Picker label (352-353): add `[%s]` for the priority
  ->
  `printf '%s\t%s\t%s\t%s\t[%s] %-24s [%s] %s%s\n' "$group" "$id" "$mgr" "$pkg" "$group" "$id" "$prio" "$mgr" "$state"`.
  The loop that builds the menu must read the 5th field. Change line 341
  `while IFS=$'\t' read -r group id mgr pkg || [ -n "$group" ]; do` to
  `while IFS=$'\t' read -r group id mgr pkg prio || [ -n "$group" ]; do`.
  Otherwise `pkg` takes `pkg \t prio` and the label breaks. `choose()`
  header (246): add ` · type "p1" to filter a tier`. `print_help` (34-55):
  document `--priority LIST` (repeatable/comma-separated; selects that tier
  automatically; has priority over --all; works with --group; steps without
  `# prio:` are excluded). Do not change `--all`, `--group`, or the fallback
  menu's selection behavior beyond the label.
  Parallelization: Wave 3 | Blocked by: 2 | Blocks: 4
  References: `setup-os` lines 31-73 (cli), 327-331 (group filter),
  341-354 (menu build), 241-252 (choose), 34-55 (help).
  Acceptance criteria:
  - `./setup-os --list --priority p1` shows only rows with PRIORITY `p1`
  - `./setup-os --list --priority p1 --priority p2` shows p1+p2
  - `./setup-os --dry-run --priority p1` prints a "Will install" list.
    It contains exactly the 11 p1 ids (git zsh tmux fzf bat fd ripgrep eza
    sd fastmod gh).
  - `./setup-os --dry-run --priority p9; echo $?` prints the die message
    and exits non-zero.
  QA scenarios: success = the four commands above. The dry-run needs no
  sudo. The run is read-only until confirm. Failure = `./setup-os --dry-run
  --priority bogus` is rejected at parse. `./setup-os --dry-run
  --priority p9` exits non-zero with the "no entries" message.
  Evidence: `.omo/evidence/task-3-os-setup-customization.txt`
  Commit: Y | `setup-os: add --priority tier auto-selection`

- [x] 4. `setup-os`: auto-run the rustup step before the cargo batch on fresh boxes
  What to do / Must NOT do: the decision and the PICKED removal must happen
  RIGHT AFTER PICKED is built and BEFORE the `echo 'Will install:'` block
  (setup-os:378-380). That block prints the list the user sees. A removal
  inside the later batch loop (399+) can never change it. Insert there:
  `if awk -F'\t' '$3=="cargo"' "$PICKED" | grep -q . && [ -f "$STEPS/10-rustup.sh" ]; then`
  Remove the rustup step row from PICKED. The steps-last loop (417-426)
  does not check `# check:` again. So it never runs rustup a second time:
  `awk -F'\t' -v rp="$STEPS/10-rustup.sh" '$4 != rp' "$PICKED" > "$PICKED.t" && mv "$PICKED.t" "$PICKED"`.
  This removal runs whenever a cargo batch will execute (with or without
  cargo present). It also makes sure of the safety rule "never run rustup
  when cargo succeeds". The step runs only through the auto path below.
  Then, still in that block:
  `if ! command -v cargo >/dev/null 2>&1; then RUN_RUSTUP_AUTO=1; fi`.
  In the install loop's `mgr=cargo` block (404-407): when
  `[ -n "$RUN_RUSTUP_AUTO" ]`, print
  `== step: rustup (auto, required by cargo) ==` and run
  `( set +e; bash "$STEPS/10-rustup.sh" ) || FAILED="$FAILED step:rustup(auto)"`.
  Under `--dry-run`, print `   [dry-run] rustup (auto, required by cargo)`
  and skip. Comment: this fires even under `--packages-only`/`--group
  cargo`, because cargo installs are impossible without cargo.
  Do not change step ordering for any other step. Do not auto-run the step
  when `command -v cargo` succeeds.
  Parallelization: Wave 4 | Blocked by: 3 | Blocks: —
  References: `setup-os` lines 341-362 (PICKED build), 378-380 (Will install
  print), 399-413 (batch loop), 417-426 (steps-last loop),
  `setup/steps/10-rustup.sh` (`# check: command -v cargo`).
  Acceptance criteria:
  - `bash -n setup-os`
  - On this machine (cargo present): `./setup-os --dry-run --priority p1`
    prints no auto-rustup line. The "Will install" list does not contain
    the rustup step row. The removal runs with or without cargo.
  - With cargo hidden from PATH (see QA): it prints
    `[dry-run] rustup (auto, required by cargo)` exactly once. The
    "Will install" list no longer contains the rustup step line.
  QA scenarios: success = normal dry-run. Failure = hide cargo: if
  `command -v cargo` lives under a user dir (example: ~/.cargo/bin - rustup),
  strip exactly that dir:
  `PATH="$(printf '%s\n' "$PATH" | tr ':' '\n' | grep -v '^'"$(dirname "$(command -v cargo)")"'$' | paste -sd:)" ./setup-os --dry-run --priority p1`
  Check that the auto line appears once. Check that the Will-install list
  lacks the rustup row. Check that the later steps section does not list
  rustup again. Restore PATH after. If cargo resolves to a system dir
  (/usr/bin etc.) or is absent, skip the PATH game. Check by code
  inspection instead. Record that in the evidence file.
  Evidence: `.omo/evidence/task-4-os-setup-customization.txt`
  Commit: Y | `setup-os: auto-run rustup before the cargo batch on fresh boxes`

- [x] 5. `setup/steps/*.sh`: add `# prio:` headers to all 14 existing steps
  What to do / Must NOT do: add `# prio: pN` as a new line after the LAST
  header line of each file (`# desc:` / `# os:` / `# check:`). The files
  have different subsets. Example: 98-macos-defaults.sh has only `# desc:`
  and `# os:`, no `# check:`. Exact assignments: p1 = 00-homebrew,
  01-xcode-clt, 02-paru, 10-rustup, 20-oh-my-zsh, 80-tpm · p2 =
  30-ranger-devicons, 60-cht-sh, 70-volta, 90-pyenv, 95-pnpm · p3 =
  40-wallpapers, 50-alacritty-themes, 98-macos-defaults. Do not touch any
  other line. Do not renumber files.
  Parallelization: Wave 1 | Blocked by: — | Blocks: —
  References: `setup/steps/` (14 files; header convention seen in
  `setup/steps/60-cht-sh.sh` lines 2-4).
  Acceptance criteria:
  - `grep -l '^# prio:' setup/steps/*.sh | wc -l` == 14
  - `grep -h '^# prio:' setup/steps/*.sh | sort | uniq -c` matches the
    table (6x p1, 5x p2, 3x p3)
  - `for f in setup/steps/*.sh; do bash -n "$f" || exit 1; done` passes.
  QA scenarios: success = the three commands. Failure = check that every
  file has prio exactly once: `grep -c '^# prio:' setup/steps/*.sh | grep -v ':1$'`
  is empty.
  Evidence: `.omo/evidence/task-5-os-setup-customization.txt`
  Commit: Y | `setup: tag steps with p1-p4 priorities`

- [x] 6. `setup/steps/`: add opencode and claude-code native-installer steps
  What to do / Must NOT do: make `setup/steps/61-opencode.sh`:
  `#!/usr/bin/env bash`, `# desc: opencode (AI coding agent)`, `# os: any`,
  `# check: command -v opencode`, `# prio: p1`, `set -euo pipefail`,
  `curl -fsSL https://opencode.ai/install | bash`. Make
  `setup/steps/62-claude-code.sh` in the same way: desc
  `claude code (AI coding agent)`, `# check: command -v claude`, body
  `curl -fsSL https://claude.ai/install.sh | bash`. Run `chmod +x` on both.
  Do not add npm/AUR/brew entries to packages.list. Decision: native
  installers. They are vendor-recommended in 2026. They need no Node.
  They update automatically. They work on any distro. Do not use `sudo`.
  Parallelization: Wave 1 | Blocked by: — | Blocks: —
  References: vendor install docs - opencode.ai/docs + github
  anomalyco/opencode: `curl -fsSL https://opencode.ai/install | bash`;
  code.claude.com/docs + github anthropics/claude-code:
  `curl -fsSL https://claude.ai/install.sh | bash` (npm deprecated).
  Step template: `setup/steps/60-cht-sh.sh`.
  Acceptance criteria:
  - `bash -n setup/steps/61-opencode.sh setup/steps/62-claude-code.sh`
  - `./setup-os --list | grep -E 'opencode|claude code'` prints the two
    rows with mgr `step` (column 3, i.e. `$3=="step"`).
  NOTE: the wave-1 check is only that the rows are present. The PRIORITY-p1
  check moves to the final wave F1. The PRIORITY column is added by todo 2
  (wave 2). Do not check `(done)` hiding: `--list` exits before
  `--show-installed` is read. So rows are never hidden under `--list`.
  QA scenarios: success = `--list` + grep. Failure = none of the agent
  install actually runs. Use dry-run only:
  `./setup-os --dry-run --priority p1`. Check that both steps appear in
  "Will install".
  Evidence: `.omo/evidence/task-6-os-setup-customization.txt`
  Commit: Y | `setup: add opencode and claude-code install steps`

- [x] 7. `link-files.bash`: replace the node `list-files.mjs` lister with a bash lister
  What to do / Must NOT do: FIRST capture the baseline:
  `./link-files.bash --dry-run > /tmp/opencode/link-before.txt`. Then delete
  `LISTER=...` (line 39). Run `git rm list-files.mjs`. Rewrite `list_root()`
  (114-121): it now takes only `$1` = root. Build the ignore set once in
  `collect()` into a new temp `IGN_TMP`. Add it to the current trap at
  124-127. Use
  `printf '%s\n' "${ignores[@]}" | sed 's#^\./##; s#/$##' > "$IGN_TMP"`.
  Then:
  ```
  find "$root" -type f 2>/dev/null \
    | awk -v r="$root" '
        NR == FNR { ign[$0] = 1; next }
        { rel = substr($0, length(r) + 2)
          if (rel ~ /^!/) next
          for (i in ign)
            if (rel == i || index(rel, i "/") == 1) { skip = 1; break }
          if (!skip) print rel
          skip = 0 }' "$IGN_TMP" - \
    | sort \
    | awk -v r="$root" 'BEGIN { OFS = "\t" } { print r, $0 }'
  ```
  After the pipeline, warn on symlinks (the same as the old lister):
  `find "$root" -type l 2>/dev/null | while IFS= read -r l; do printf 'skip symlink: %s\n' "${l#$root/}" >&2; done`.
  Update the file header comment (lines 3-10) to note the lister is pure
  bash/POSIX (no node). Ignore-list behavior is kept: exact relpath or a
  subtree of a directory entry. Unknown file types (fifo/socket) are now
  skipped without an error instead of the mjs error-exit-1. This is on
  purpose. Note it in a comment. Do not change `read_ignores`. Do not
  change `collect()`'s overlay/dedup awk. Do not change `link-ignore.txt`.
  Do not change any classification logic.
  Parallelization: Wave 1 | Blocked by: — | Blocks: 8
  References: `link-files.bash` lines 3-10, 36-40, 114-146, 149-152;
  `list-files.mjs` (whole, esp. 21-52, 61-82 - behavior to copy);
  `link-ignore.txt`.
  Acceptance criteria:
  - `bash -n link-files.bash`
  - `diff <(grep -E '^[+*~!-] ' /tmp/opencode/link-before.txt | awk '{print $2}' | sort -u) <(./link-files.bash --dry-run | grep -E '^[+*~!-] ' | awk '{print $2}' | sort -u)`
    is empty (the same set of files to link)
  - `./link-files.bash --dry-run '.*nvim.*'` still narrows to nvim paths
  - Linking works with node absent: put a failing node stub in PATH first -
    `mkdir -p /tmp/opencode/fakebin; printf '#!/bin/sh\nexit 1\n' > /tmp/opencode/fakebin/node; chmod +x /tmp/opencode/fakebin/node; PATH=/tmp/opencode/fakebin:$PATH ./link-files.bash --dry-run`
    exits 0 and matches the baseline set. If the script still called node,
    the stub would exit 1 and the run would fail.
  QA scenarios: success = the four commands. Failure = symlink warning
  path: `ln -s nvim common/bin/zz-test-link`. Run
  `./link-files.bash --dry-run`. Stderr contains
  `skip symlink: bin/zz-test-link`. Run `rm common/bin/zz-test-link`.
  Evidence: `.omo/evidence/task-7-os-setup-customization.txt`
  Commit: Y | `link-files: replace node list-files.mjs with a bash lister`

- [x] 8. `link-files.bash`: interactive picker with select/deselect-all shortcuts
  What to do / Must NOT do:
  (a) Track `pattern_given=1` in `parse_args` when a positional pattern is
  read. The picker runs when
  `[ -z "$is_dry" ] && [ -z "$is_yes" ] && [ -z "$pattern_given" ]`. There
  is NO `-t 0` check in the gate. Stdin from a pipe still selects through
  the fallback menu. The tty check decides fzf-vs-fallback INSIDE the
  picker. Use fzf only when `[ -t 0 ] && command -v fzf >/dev/null 2>&1`.
  Otherwise use the numbered fallback. So piped input, cron, CI and
  machines without fzf all take the fallback path. No PATH hiding is needed.
  (b) After `collect()`, before `classify()`: build the menu from
  `$merged`. Line format `rel \t [<group>] rel`. Get the group with awk:
  `.config/<x>/*` -> `<x>`; `bin/*` -> `bin`; `.tmux.conf` -> `tmux`;
  `.gitconfig|.gitignore_global|.config/git/*` -> `git`;
  `.bashrc|.bash_profile|.zshrc|.profile|.hushlogin|.config/shell/*` ->
  `shell`; `.Xmodmap|.xinitrc` -> `x11`; else `other`.
  (c) fzf path:
  `fzf --multi --delimiter=$'\t' --with-nth=2.. --height=90% --reverse --tiebreak=index --prompt='link> ' --header='TAB toggle · CTRL-A select all matches · CTRL-D deselect all · ENTER link' --bind "$(picker_bind)" | cut -f1`.
  `picker_bind` returns
  `ctrl-a:select-all,ctrl-d:deselect-all,start:select-all` when fzf is
  0.48 or more. Otherwise it returns the same minus `start:`. Version
  check (bash 3.2-safe, no `<<<`, no `sort -V`):
  `fzf_ge() { local v vma vmi ma mi; v="$(fzf --version 2>/dev/null | awk '{print $1}')"; IFS=. read -r vma vmi _ < <(printf '%s\n' "${v:-0}"); IFS=. read -r ma mi _ < <(printf '%s\n' "$1"); if [ "${vma:-0}" -gt "${ma:-0}" ] || { [ "${vma:-0}" -eq "${ma:-0}" ] && [ "${vmi:-0}" -ge "${mi:-0}" ]; }; then return 0; else return 1; fi }`.
  Preselect-all on start = `start:select-all` (fzf 0.48 or more only).
  Older fzf starts empty - README note. This machine's fzf is 0.44.1, so
  the picker starts empty here. The selection stays across query changes.
  Native fzf behavior: ctrl-a selects all *current matches*. Clearing the
  query keeps them.
  (d) Fallback: copy `menu_fallback` + `expand_selection` from `setup-os`
  (256-313). Adapt the input source:
  `if [ -t 0 ]; then read -r sel </dev/tty; else read -r sel; fi`.
  setup-os fixes `</dev/tty`. Without this adaptation, piped input never
  reaches the menu. Behavior: empty input = ALL, `n` = none, `a` = all,
  numbers/ranges. Hint line: `'a' = all (default) · 'n' = none · numbers
  and ranges · empty = all`.
  (e) Plumbing: picked relpaths -> `$PICKED_LINKS` temp (add to trap).
  If the picker ran and nothing was selected ->
  `echo 'Nothing selected.'; exit 0`. Else narrow `$merged` with
  `awk -F'\t' 'NR==FNR { p[$0] = 1; next } $2 in p' "$PICKED_LINKS" "$merged" > "$merged.tmp" && mv "$merged.tmp" "$merged"`.
  Add `"$merged.tmp"` to the trap. Do not use a bare `t` in the repo root.
  Rebuild `$mdirs` from the parents of the picked relpaths. Apply the sub
  AFTER you add `$HOME`:
  `awk -v h="$HOME" '{ p = h "/" $0; sub(/\/[^\/]*$/, "", p); print p }' "$PICKED_LINKS" | sort -u > "$mdirs"`.
  So top-level files (`.bashrc`) map to `$HOME`. This matches the current
  line 144 formula. The removal of old links stays inside the choice.
  (f) Update `print_help` (46-70) with a paragraph on interactive
  selection.
  Do not change the `--force`/`--dry-run`/`--yes`/pattern behavior. Those
  paths keep linking everything or filtering as today.
  Parallelization: Wave 2 | Blocked by: 7 | Blocks: 9
  References: `link-files.bash` lines 42-96 (cli), 114-146 (collect),
  194-213 (find_stale), 336-342 (main); `setup-os` lines 241-252 (choose),
  256-313 (fallback menu to adapt); fzf docs: `start` event added in 0.48.0.
  Acceptance criteria:
  - `bash -n link-files.bash`
  - Non-interactive fallback with stdin from a pipe. No tty -> fallback
    path. No fzf hiding needed. `mkdir -p /tmp/opencode/fakehome1`.
    `printf '1 2\ny\n' | HOME=/tmp/opencode/fakehome1 ./link-files.bash`
    makes exactly the first two menu entries as symlinks in the test HOME.
    The fallback reads `1 2` from the pipe. The confirm `read -r -p`
    reads the trailing `y`.
  - `printf 'n\n' | HOME=/tmp/opencode/fakehome1 ./link-files.bash` prints
    `Nothing selected.` and exits 0 (no symlinks added).
  - `printf '\ny\n' | HOME=/tmp/opencode/fakehome2 ./link-files.bash`
    (empty = ALL) links everything into fakehome2.
  - fzf_ge check:
    `printf '#!/bin/sh\necho 0.47.0\n' > /tmp/opencode/fakebin/fzf; chmod +x /tmp/opencode/fakebin/fzf; PATH=/tmp/opencode/fakebin:$PATH bash -c 'source <(sed -n "/^fzf_ge/,/^}/p" link-files.bash); fzf_ge 0.48 || echo OLD'`
    prints OLD. With `echo 0.48.1` it prints nothing, exit 0.
  QA scenarios: success = the non-interactive fallback runs above +
  tmux-driven real fzf run. New tmux session: `mkdir -p
  /tmp/opencode/fakehome2; HOME=/tmp/opencode/fakehome2
  ./link-files.bash`. Type `nvim`, `ctrl-a`, `ctrl-u` to clear the query,
  `enter`, then `y` at the confirm prompt. Capture-pane. Check that only
  `nvim`-related symlinks exist under fakehome2. Repeat with `ctrl-d`
  first to check deselect-all. On this machine fzf is 0.44.1 (< 0.48). So
  the picker starts EMPTY and the sequence is exactly right as written.
  Failure = check that fakehome2 has no non-nvim links (scope check).
  Evidence: `.omo/evidence/task-8-os-setup-customization.txt`
  Commit: Y | `link-files: add interactive picker with select/deselect-all shortcuts`

- [x] 9. `README.md`: document priorities and interactive linking
  What to do / Must NOT do: "Installing programs" (103-135): document the
  `pN` token in the packages.list example block. Add a small tier table
  (p1 SSH essentials + agents / p2 dev workstation / p3 GUI / p4
  occasional). Add `--priority` examples (`./setup-os --priority p1 -y`
  for a temp machine; `./setup-os --priority p1,p2`). Note that steps may
  carry `# prio:`. Note that rustup runs automatically before cargo
  packages on fresh boxes. "Linking" (36-101): add an "Interactive
  selection" paragraph. Bare `link-files.bash` opens an fzf picker over
  all linkable files with `[group]` labels. Type to filter. `CTRL-A`
  selects all current matches. Selections stay when the query is cleared.
  `CTRL-D` deselects all. TAB toggles. fzf 0.48 or more starts with
  everything selected (older: press `CTRL-A`). Fallback numbered menu with
  `a`/`n`. A `<pattern>` arg or `--dry-run`/`--yes` skips the picker.
  Note that the linker no longer needs node. Do not rewrite the substance
  of any other section.
  Parallelization: Wave 5 | Blocked by: 8 | Blocks: —
  References: `README.md` lines 36-135.
  Acceptance criteria:
  - `grep -q -- '--priority' README.md && grep -q -- 'p1' README.md`
  - `grep -qi 'starts with everything selected' README.md`. This is the
    human phrasing the todo text needs. Do not require the literal
    `start:select`; that is an implementation detail.
  - `grep -q 'no longer needs node\|no node' README.md`
  - Markdown renders: `npx markdownlint-cli2 README.md 2>/dev/null || true`.
    This is information only. No markdownlint installed. Do not fail on it.
  - Check visually that the code fences are balanced.
  QA scenarios: success = grep checks + check the text with `read`.
  Failure = the "Linking" usage block still shows the current
  `link-files.bash` invocations. They stay valid. The picker is additive.
  Evidence: `.omo/evidence/task-9-os-setup-customization.txt`
  Commit: Y | `README: document priority tiers and interactive linking`

## Final verification wave
> Runs in parallel after ALL todos. ALL must APPROVE. Surface results and wait for the user's explicit okay before declaring complete.
- [x] F1. Plan compliance check - check every todo: all 9 done with evidence
  files present. Run the acceptance criteria again without a terminal:
  - `bash -n` on both scripts
  - `./setup-os --list` shows PRIORITY
  - `--dry-run --priority p1` lists the 11 p1 ids
  - lister baseline diff still empty
  - test-HOME fallback tests pass
- [x] F2. Code quality review - grep the diffs (`git diff HEAD~9..HEAD`) for
  bash 3.2 violations (`<<<`, `mapfile`, `declare -A`, `${v,,}`, `sort -V`,
  `find -mindepth`) and for dead code (old LISTER refs, leftover
  `list-files.mjs` references). Check that `setup-os` and `link-files.bash`
  still pass `bash -n` on the committed state.
- [x] F3. Real manual QA - tmux-driven: `link-files.bash` in a test HOME:
  type `nvim`, CTRL-A, clear query, CTRL-A again on another group, ENTER,
  `y` at the confirm prompt. Check that the selection stayed. Check that
  only the chosen relpaths got symlinked. This machine's fzf 0.44.1 starts
  empty, so the sequence is valid as written. Also run
  `setup-os --dry-run --priority p1 -y` end-to-end on this machine
  (read-only). Check the todo 6 check that moved here: `--list` rows for
  `opencode`/`claude code` show PRIORITY `p1` (column 3).
- [x] F4. Scope check - `git diff HEAD~9..HEAD --stat`: exactly
  `setup/packages.list`, `setup-os`, `setup/steps/*.sh` (14 prio headers +
  2 new), `link-files.bash`, `list-files.mjs` (deleted), `README.md`.
  Nothing under `common/`, `linux/`, `macos/`. No stray files. Compare
  against the plan's Must-not-do list.

## Commit strategy
One commit per todo, in todo order. Repo style ("Area: description" per
`git log --oneline`):
1. `setup: add p1-p4 priority labels to packages.list`
2. `setup-os: resolve and display package priorities`
3. `setup-os: add --priority tier auto-selection`
4. `setup-os: auto-run rustup before the cargo batch on fresh boxes`
5. `setup: tag steps with p1-p4 priorities`
6. `setup: add opencode and claude-code install steps`
7. `link-files: replace node list-files.mjs with a bash lister`
8. `link-files: add interactive picker with select/deselect-all shortcuts`
9. `README: document priority tiers and interactive linking`
Never amend a commit that a later todo depends on. Each commit must leave
the repo functional: `bash -n` + `--list` pass at every commit boundary.

## Success criteria
1. `./setup-os --priority p1 -y` (dry-run checked) installs exactly the p1
   essentials - git, zsh, tmux, fzf, bat, fd, ripgrep, eza, sd, fastmod,
   gh - plus rustup (auto), the p1 steps (rustup/oh-my-zsh/tpm, paru on
   Arch, homebrew+xcode-clt on macOS), and the opencode + claude-code
   agents.
2. `setup-os` picker rows show `[p1]`..`[p4]` (typing `p1` filters).
   `--list` shows a PRIORITY column. `--priority` works with `--group`
   and `-y`.
3. `link-files.bash` bare = interactive picker: CTRL-A selects all current
   matches, the selection stays when you clear the query, CTRL-D deselects
   all, ENTER links only the choice. The fallback menu works with no fzf.
   If you select nothing, the script exits cleanly.
4. `link-files.bash` gives the same set of files to link as the old node
   lister (baseline diff empty) and runs with node absent from PATH.
5. README documents tiers, `--priority`, the picker shortcuts, and the
   no-node lister.
