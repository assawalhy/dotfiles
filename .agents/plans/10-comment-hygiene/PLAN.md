# Plan: comment hygiene — abide by global `## Comments`

## Goal

Every comment in the repo's code files is either (a) a strictly necessary
hidden decision, (b) structure (section banner, one-line file header), or
gone — and every kept comment obeys `## Writing style`.

## Policy (applied verbatim by every batch)

**KEEP** — deleting it would lose:
- a constraint not visible in the code (bash 3.2 compat, no node, no sudo on
  NixOS, EXTERNALLY-MANAGED);
- a safety invariant, i.e. why a guard exists ("only ever touches links whose
  target is under $REPO");
- a deliberate choice/deviation (known-issue bug behavior in tests, a config
  value that differs from the default because X, "Deliberate.");
- an empirical number (measured <100 ms);
- the gotcha an odd construct exists for (`grep && continue` under `set -e`);
- structure: section banners (`# ---- refresh ----`), one-line file header
  stating purpose.

**KEEP-ONCE**: same rationale twice → keep only the instance at the code it
governs.

**DELETE**: narration of the next line; restated code; obvious labels;
history recoverable from `git blame`; text that only duplicates README/AGENTS
with no decision anchored to a specific line.

**REWRITE** (kept comments must satisfy `## Writing style`): literal English,
no "silently/quietly/magic/trap/wedge/bites/catastrophic/under the hood", no
anthropomorphism (code doesn't want/know/decide/try), no metaphor or idiom,
name the concrete thing, one claim per sentence. Applies to test names and
known-issue texts too: "silently moves a home file" → "moves a home file
without reporting it".

**NOT COMMENTS (untouched)**: shebangs and `set` lines; all markdown
(README, AGENTS, PLAN/TODO); vendored `common/.config/ranger/scope.sh`
(upstream ranger's file: "left untouched if you upgrade ranger"); config
dotfiles (`.tmux.conf`, gitconfig, alacritty, ranger rc); data files
(`setup/packages.list`, `setup/agent-skills.list`, `link-ignore.txt`);
`.agents/plans/**`.

## Approach — 4 batches, disjoint files, parallel

```
A  link-files.bash + tests/*          (~350 comment lines, judgment-heavy)
B  setup-os + setup/*.sh + setup/steps/*.sh   (~250, incl. 91-uv-python.sh)
C  configuration.nix + shell rc/os files       (~180, incl. the new unit)
D  nvim *.lua (19 files) + common/bin/* + linux/bin/* (~150)
            │  each sub-agent reads this PLAN.md, applies the policy,
            │  reports keep/delete/rewrite counts per file
            ▼
coordinator validates every diff (git diff --stat + spot reads), ticks TODO
            ▼
final verification: bash -n · nix-instantiate --parse · bats (99/5/known-issues)
                    · tests/nvim-smoke.bash
```

## Decisions

- **Moderate strictness** (user choice): section banners and file headers
  survive with the hidden-decision exception; narration goes.
- **Code only**; vendored `scope.sh` and markdown excluded (documentation,
  not comments).
- **New epic** `10-comment-hygiene` (no active epic matches).
- **No commits** — global rule: never commit unless asked; the tree also
  holds pending epic-09 work.

## Risks

- Knowledge loss by over-deletion → policy is keep-biased for decisions, I
  review every diff before ticking, git history keeps the originals.
- `tests/link-known-issues.bats` comments *are* the bug documentation → must
  survive (style rewrite only).
- Parallel batches share the working tree → strictly disjoint file lists in
  TODO.md; only the coordinator writes TODO.md.
- Epic 09 TODO 6–7 (nixos-rebuild hand-off) stays pending — orthogonal to
  this epic, resumed whenever the user runs `sudo -v`.
