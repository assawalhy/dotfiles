# Notepad: os-setup-customization

## learnings.md
- Repo: dotfiles (macOS + Linux). Scripts must stay bash 3.2 compatible: no `<<<`, `mapfile`, `declare -A`, `${v,,}`, globstar, `sort -V`, `find -mindepth`.
- No test infra in repo. QA vehicles: `bash -n`, `--dry-run`, `--list`, headless fallback-menu input, tmux-driven picker QA.
- Git repo style: `Area: description` commit messages. Commit only when the todo says Commit: Y.
- Evidence files: `.omo/evidence/task-<N>-os-setup-customization.txt` (commands + outputs).
- fzf on this machine: 0.44.1 (< 0.48). Picker must start EMPTY here; `start:select-all` only for >= 0.48.
- Test HOMEs under /tmp/opencode. NEVER touch real $HOME. NEVER run real installs.
- Baseline capture for T7: `/tmp/opencode/link-before.txt` taken at START of todo 7, before any edit to link-files.bash. (ALREADY CAPTURED by orchestrator 2026-08-14: 73 lines, 69 linkable entries.)

## Task 5 (wave 1) — prio headers (Sisyphus, 2026-08-14)
- Added `# prio: pN` after the last header line of all 14 step files (6x p1, 5x p2, 3x p3). 98-macos-defaults.sh has no `# check:` so prio goes after `# os:`.
- 61-opencode.sh/62-claude-code.sh appeared mid-task from a parallel worker (both p1) — excluded from this task's edits and commit.
- GOTCHA: rewriting step files via `awk > tmp && mv` silently strips the exec bit (100755 → 100644). The step scripts may be invoked directly (`./step.sh`), so modes matter. If editing any setup/steps file, use in-place edit tooling (sed -i / perl -pi) or re-`chmod +x` after writing, and check `git diff --stat` for mode changes before committing. Restored exec bits in follow-up commit 6947bde.
- Commit style used: "setup: ..." per repo convention; committed as 76eeade + 6947bde.
- T1 (packages.list pN tokens, commit e4acfd3): pN token is the LAST whitespace token, before any `#` comment. Resolver strips comments first (setup-os:175), so a token after a comment is invisible. setup-os locates the list via `$REPO/setup/packages.list` (self_dir = script dir). Tier counts locked: p1=11, p2=19, p3=15, p4=6 (51 lines). Resolver ignores unknown whitespace tokens, so --list output is byte-identical with pN added.
- T6 (done 2026-08-14): added setup/steps/61-opencode.sh (https://opencode.ai/install) + 62-claude-code.sh (https://claude.ai/install.sh), native installers, os:any, check: command -v, prio:p1, chmod +x.
- setup-os --list output is FIXED-WIDTH (printf %-10s %-22s %-8s %s, line 335), NOT tab-delimited. The raw tab format lives only in $TMP. The ID column overflows 22 chars when the desc contains spaces, so positional/cut parsing is fragile; parse GROUP=$1, MANAGER=$(NF-1).
- --list exits at line 337 BEFORE the step_done() ' (done)' eval (line 344), so rows are never hidden under --list; resolve_steps() (214-228) only sed-reads # os:/# desc: headers, never executes bodies.
- opencode & claude binaries ALREADY present on this host (/home/ms/.bun/bin/opencode, /home/ms/.local/bin/claude) from earlier manual installs - not by this todo.
- T7 done (2026-08-14, commit 977020f): bash lister replaced list-files.mjs. The `git rm` did NOT stick in the index (hook interference) -- restaged with `git add -A link-files.bash list-files.mjs`. If staging ever looks off, check `git diff --cached`; a parallel hook may reset it.
- New lister emits the `skip symlink:` warning twice for common/ (collect lists common once, mdirs block lists it again) -- same multiplicity the old node lister had; acceptance only needs the string present on stderr.
- Empty ignores array: `printf '%s\n' "${ignores[@]}"` writes one blank line to IGN_TMP; harmless in the awk (empty ign key never equals a relpath, and `index(rel, "/")==1` can't fire since rel never starts with /).
- `find -type f` means fifos/sockets are silently dropped (old mjs exited 1); intentional per plan.
- T5 squashed: exec-bit restore folded into prio-header commit (6947bde -> fixup into 76eeade) to keep 9-commit plan contract.

## Task 2 (wave 2) — resolve/display priorities (Sisyphus, 2026-08-14)
- resolve() awk: prio must be reset per record (`id = $1; skip = 0; prio = ""`) or a token-less line inherits the previous line's prio (would break the documented p4 default). Capture `if ($i ~ /^p[0-9]+$/) { prio = $i; continue }` goes BEFORE the colon check (line 184) because pN tokens are bare (no colon) and would otherwise be skipped.
- pN is the LAST whitespace token before any `#` comment; the resolver strips comments first (line 175), so a token written after a comment is invisible.
- 5th field emitted by resolve(): `(prio ? prio : "p4")` in both cargo/pip branch and main branch; resolve_steps() emits empty string when no `# prio:` header. Picker/installer read only $1-$4, so the extra field is inert there (menu label is arg 5 in printf, unaffected).
- --list printer now maps fields $1 $2 $5 $3 $4 (PRIORITY %-6s between ID and MANAGER). Columns are SPACE-aligned, not tab-delimited; awk field splits on whitespace runs so positional parsing still works.
- Failure-mode QA: stripping `p1` from the git line makes it resolve p4; `git checkout -- setup/packages.list` restores.

## Task 8 (wave 2) — link-files interactive picker (Sisyphus, 2026-08-14, commit ac18ecb)
- fzf --multi Enter ALWAYS emits the current (highlighted) item even with zero marks: `C-a, C-d, Enter` links exactly 1 file (the current item). Deselect-all DID drop the other 12. So "Nothing selected." from fzf only fires on no-match query / ESC, not on ctrl-d. Verified with `printf 'a\nb\nc\n' | fzf --multi --bind 'ctrl-a:select-all,ctrl-d:deselect-all'` (C-a,C-d,Enter -> outputs "a").
- The /dev/tty display block in menu_fallback leaks a bash diagnostic in headless runs ("/dev/tty: No such device or address") UNLESS the redirection order is `2>/dev/null >/dev/tty` (redirections apply left-to-right; the failure message goes to fd 2, so it must already be /dev/null). zsh prints the same diagnostic regardless of order — test redirection-suppression inside bash, not the outer zsh.
- menu_fallback adaptation that made piped input work: the menu is read from a FILE ARG (`done < "$menu_file"`), NOT from stdin — stdin (fd 0) stays free for the selection read (`[ -t 0 ]` ? `/dev/tty` : stdin). setup-os's original reads the menu on stdin AND the selection from /dev/tty, which breaks under a pipe with no controlling tty.
- Group extraction for the fallback headers with single-bracket labels `[git] rel`: `${labels[$i]#[}` + `${group%%]*}` (setup-os's `${x%%]*]}` needs TWO `]` and returns the whole label for one-bracket labels).
- expand_selection differs from setup-os on empty: setup-os empty = none; this task's spec made empty = ALL (hint line: "'a' = all (default) · 'n' = none · numbers and ranges · empty = all").
- fzf --version on this box prints "0.44.1 (debian)" -> `awk '{print $1}'` is required before the IFS=. read.
- The `start:select-all` bind (fzf >= 0.48) is version-gated via fzf_ge; on 0.44.1 picker_bind returns ctrl-a/ctrl-d only, and the picker starts EMPTY (QA run 1 needed the explicit C-a).
- Evidence: .omo/evidence/task-8-os-setup-customization.txt (all 6 acceptance criteria + skip-gate checks + tty-fallback menu QA).

## Task 3 (wave 3) -- --priority tier auto-selection (Sisyphus, 2026-08-14)
- --priority parsing: repeatable flag, one arg each; comma-split via ${v%%,*}/${v#*,} while loop (bash 3.2 safe); each piece validated with `case "$piece" in p[0-9]*)` else `die "invalid priority \"$piece\""`; accumulates `prios` with a LEADING space (" p1 p2").
- Tier filter mirrors the --group filter exactly: `pat="$(printf '%s' "$prios" | sed 's/^ //; s/ /|/g')"` then `awk -F'\t' -v p="^($pat)$" '$5 ~ p' "$TMP" > "$TMP.f" && mv`. The anchored regex is what excludes steps without `# prio:` (resolve_steps emits an EMPTY 5th field for them); empty 5th field never matches.
- want_all=1 is set inside the `[ -n "$prios" ]` filter block, BEFORE the menu-build skip logic (line ~350), so done entries are NOT hidden and everything in the filtered TMP is selected (same as --all). --priority + --all = --all restricted to the tier (priority wins because prios filters TMP first).
- die message uses `"no entries match priority${prios}"` (no space before ${prios}) so the leading space in prios produces the clean "no entries match priority p9" -- the brief's literal `"priority $prios"` would emit a double space.
- ACCEPTANCE DISCREPANCY (important for T4): the plan says the p1 dry-run Will-install "contains exactly the 11 p1 ids" -- that count comes from packages.list (T1: p1=11 PACKAGES). On this machine the p1 TIER (filtered TMP) = 11 packages + 6 steps (paru/rustup/oh-my-zsh/opencode/claude/tpm, all os:any|linux with # prio: p1). With want_all=1 the dry-run therefore prints 17 rows. Verified the 11 package ids are exactly git zsh tmux fzf bat fd ripgrep eza sd fastmod gh via `--list --priority p1 | awk 'NR>1 && $(NF-1)!="step" {print $2}'` (the $(NF-1)!=step guard is REQUIRED: multi-word step ids shift columns, e.g. "opencode (AI coding agent)" puts p1 at $6). This behavior is spec-correct; T4 must remember steps are part of the p1 tier.
- --list --priority works (filter runs before the --list printer); --list --priority p9 dies with the no-entries message rather than printing an empty table.
- picker label now `[%s] %-24s [%s] %s%s` (group, id, PRIO, mgr, state); the menu-build read loop must read 5 fields or pkg swallows "pkg\tprio".
- fzf header gained ` · type "p1" to filter a tier`.
- Evidence: .omo/evidence/task-3-os-setup-customization.txt (all 4 acceptance + bogus-parse failure mode + id-set diff).

## Task 4 (wave 4) -- auto-run rustup before the cargo batch (Sisyphus, 2026-08-14)
- Block A goes RIGHT AFTER PICKED is built (after the n_skipped notice, before `echo 'Will install:'`): `if awk -F'\t' '$3=="cargo"' "$PICKED" | grep -q . && [ -f "$STEPS/10-rustup.sh" ]` drops the rustup row from PICKED (`$4 != rp`) and sets `RUN_RUSTUP_AUTO=1` only when `command -v cargo` fails. PICKED rows are `group\tid\tmgr\tpkg` (4 fields); the steps-last loop reads PICKED again and does NOT re-check `# check:`, so removing the row here is what prevents a double rustup run under --all/--priority (want_all hides nothing, so a done step's row would otherwise still appear and re-run).
- Block B goes inside the cargo iteration of the batch loop, right after the `printf '\n== %s (%d) ==\n'` header, before `pm_install`: gated `[ "$mgr" = cargo ] && [ -n "$RUN_RUSTUP_AUTO" ]`. Prints `== step: rustup (auto, required by cargo) ==` + dry-run line, or `( set +e; bash "$STEPS/10-rustup.sh" ) || FAILED="$FAILED step:rustup(auto)"` in a subshell (same set +e pattern as the steps-last loop).
- GOTCHA: plan's line refs (~378-380, ~399-426) are ~20 lines stale post-T3; locate anchors by content (PICKED build 387-393, Will install print 404, batch loop 425, steps-last 443). Actual anchors verified pre-edit.
- GOTCHA: `command -v cargo` on this box resolves to /home/ms/.cargo/bin/cargo (a 6-byte symlink to rustup). QA PATH-strip pattern: `PATH="$(printf '%s\n' "$PATH" | tr ':' '\n' | grep -v '^/home/ms/.cargo/bin$' | paste -sd:)"`. Always probe `command -v cargo` fails under the stripped PATH BEFORE running the scenario. Run in a subshell so the caller's PATH is untouched.
- GOTCHA: under --dry-run with cargo stripped, `pm_list_installed cargo` silently fails (cargo install --list -> empty cache) so all 4 cargo packages (fastmod ripgrep eza sd) show as not-installed; harmless for dry-run, they stay in the Will-install list as expected.
- Behavior spec-correct per plan: auto-rustup fires under --packages-only/--group cargo too (cargo installs impossible without cargo); NEVER fires when command -v cargo succeeds; removal of the rustup row runs with OR without cargo present.
- Evidence: .omo/evidence/task-4-os-setup-customization.txt (syntax check, cargo visibility probes, both acceptance outputs + grep -c == 1).

## Task 9 (wave 5) -- README: document priorities and interactive linking (Sisyphus, 2026-08-14, commit 92f956c)
- Additive-only edits to README.md; only README.md staged (a parallel .gitignore change adding .omo/ etc. was left unstaged).
- GOTCHA: the acceptance grep 'starts with everything selected' is newline-sensitive. My first draft wrapped the phrase across two prose lines ("starts with\n everything selected"), so `grep -qi` FAILED. Rewrapped so the phrase sits on one line, then all 4 greps passed. Any future README text that doubles as a grep target must keep the phrase on a single line.
- Fence discipline: added zero new ``` fences; extended the existing Installing programs usage block and packages.list example block in place, so the fence count stayed even (12).
- Linking usage block (USAGE: link-files.bash [--help] [--force] [--dry-run] [--yes] [filtering_pattern]) and the 4 example invocations are still valid and were left byte-identical; the picker is documented as skipping on <pattern>/--dry-run/--yes (the gate from decisions.md).
- Tier table in README mirrors decisions.md: p1 SSH essentials + agents (git zsh tmux fzf bat fd ripgrep eza sd fastmod gh + rustup/oh-my-zsh/tpm/opencode/claude steps), p2 dev workstation, p3 GUI, p4 occasional.
- rustup auto-run documented as "runs automatically right before the cargo packages" on boxes with no cargo (matches T4 behavior: fires only when `command -v cargo` fails).
