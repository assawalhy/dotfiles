# Draft: os-setup-customization

status: interviewing          # -> awaiting-approval -> approved
pending-action: (none yet)

## Request (user, verbatim intent)

1. Change structure of `setup/packages.list`: label each program/package with a
   priority level p1, p2, p3, ... and autoselect programs of a specific priority.
2. Goal: on a temp/experimental machine, don't install everything — only GUI
   apps, or only SSH essentials (eza, fzf, other terminal tools).
3. Add the two CLI coding agents: opencode and claude (Claude Code).
4. Allow choosing from the linking script (`link-files.bash`): pick which
   specific configurations get linked, with select-all / deselect-all shortcuts.

## Exploration findings (facts with paths)

- `setup/packages.list` (85 lines): sections `[terminal] [extra] [gui] [dev]
  [fonts] [cargo] [pip]`. Format: `<id> [mgr:name] [!macos] [!linux]`.
  Resolver in `setup-os` (awk, lines 171-211) emits `group \t id \t mgr \t pkg`.
  `[cargo]`/`[pip]` are special sections installed via `cargo install` / `pipx`.
- `setup-os` (434 lines, must stay bash 3.2 compatible — macOS /bin/bash 3.2.57):
  - flags: `--all --group NAME --list --show-installed --packages-only
    --steps-only -n --dry-run -y --yes`
  - picker `choose()` (lines 241-252): fzf --multi with
    `--bind 'ctrl-a:select-all,ctrl-d:deselect-all'`, else `menu_fallback`
    (numbers/ranges, "a"=all, empty=none).
  - steps `setup/steps/*.sh` with `# desc:` `# os:` `# check:` headers;
    installed LAST (lines 417-426), after all package batches.
  - Batch order: brew cask pacman aur apt dnf zypper cargo pip, then steps.
    => on a truly fresh machine, [cargo] installs run BEFORE rustup step and
    fail; must fix for the temp-machine story (auto-promote rustup).
- `link-files.bash` (342 lines, bash 3.2 compatible): links everything under
  `common/` + `linux/` or `macos/` (overlay wins). Only filter today: a regex
  `<pattern>` arg. No picker. `--dry-run`/`--yes`/pattern skip interactivity.
  `list-files.mjs` emits relpaths; `link-ignore.txt` is the exclusion list.
- Linkable surface: common/{.config/delta,.config/mpv,.config/nvim,
  .config/ranger,bin,.bash_profile,.bashrc,.gitconfig,.gitignore_global,
  .hushlogin,.tmux.conf,.zshrc} + linux/{.config/git,.config/shell,
  .config/zathura,bin,.Xmodmap,.profile,.xinitrc} + macos/{.config/git,.config/shell}.
  Natural groups: nvim, ranger, mpv, delta, git, shell, zathura, tmux, bin, x11.
- No test infra in repo (no tests/ dir). QA vehicle: `bash -n`, `--dry-run`,
  `--list`, headless fallback-menu input. fzf present on this machine.
- README.md documents both scripts in detail — must be updated.

## External facts (verified 2026-08)

- **opencode**: vendor docs (opencode.ai/docs, github anomalyco/opencode):
  easiest = `curl -fsSL https://opencode.ai/install | bash` (no Node needed);
  npm `opencode-ai`; brew `anomalyco/tap/opencode` (tap) or `brew install
  opencode` (official formula, updates less); Arch `pacman -S opencode`
  (stable) / `aur opencode-bin` (latest); NO apt/dnf package.
- **claude-code**: vendor docs (code.claude.com/docs, github anthropics/claude-code):
  recommended = `curl -fsSL https://claude.ai/install.sh | bash` (native,
  auto-updates, installs to ~/.local/bin/claude, no Node); brew cask
  `claude-code` (+`claude-code@latest`); AUR `claude-code` (community);
  apt/dnf need Anthropic signed repo setup (a step); npm
  `@anthropic-ai/claude-code` is **deprecated** by the vendor.
- Environment: fzf available, bash 5.2 here, node via volta.

## Topology lock (components)

1. packages.list — priority token format + label all ~37 entries.
2. setup-os — `--priority pN` autoselect, priority in picker/--list,
   `# prio:` for steps, rustup auto-promote before cargo batch.
3. opencode + claude-code addition (method = fork, Q2).
4. link-files.bash — interactive group picker + select/deselect-all shortcuts
   (grouping mechanism = fork, Q3).

## Two-filter analysis (candidate questions -> survive?)

- Q1 tier semantics (p1/p2/p3 meaning + table): survives — owner-decision,
  user lives with the labeled table. Default recommended: p1=SSH essentials +
  agents, p2=dev workstation, p3=GUI + heavy extras.
- Q2 agents install method: survives — cross-cutting maintenance choice.
  Default recommended: native-installer steps (vendor-recommended, distro-
  agnostic, no Node). Alt: packages.list entries; Both.
- Q3 link-files grouping: survives — maintenance-model fork.
  Default recommended: auto-derived groups (no new file, self-maintaining).
  Alt: explicit manifest `link-groups.list`; file-level only.
- Priority token syntax (bare `p1` vs `prio:p1` vs section default): adopted
  default = bare `p1` token; unlabeled => p3 (safe). Reversible internal.
- `--priority` UX (flag vs picker prompt): adopted default = flag
  `--priority p1[,p2]`, menu restricted + auto-selected (like --all scoped),
  composes with `-y` for non-interactive; picker lines show `[p1]` label so
  typing "p1" in fzf filters. Reversible internal.
- link-files default behavior: adopted default = bare `link-files.bash` opens
  picker with ALL preselected (`--bind 'start:select-all'`, fzf >= 0.48; fallback
  menu empty=all); `--dry-run`/`--yes`/regex pattern skip picker (existing
  invocations keep working). ctrl-a/ctrl-d shortcuts; fallback "a"/"n".
- Steps priorities: adopted default = optional `# prio:` header on steps;
  steps without it are unaffected by --priority; label rustup + agents p1.
- Test strategy (adopted default): tests-after none; agent-executed QA =
  `bash -n`, `--dry-run`, `--list`, headless fallback-menu runs; README
  example commands verified verbatim.

## Interview record

Turn 1 answers:
- Q1 tiers: **4 tiers** (p1 essentials / p2 dev / p3 GUI / p4 occasional-use,
  e.g. texlive, megasync, fonts). Format must support p1..pN.
- Q2 agents: **Native-installer steps** (61-opencode.sh, 62-claude-code.sh).
- Q3 linking: user-proposed UX adopted — interactive fzf picker where you type
  a filter, `ctrl-a` selects all current matches, selection persists when the
  query is cleared, accumulate across queries. Native fzf behavior. Groups are
  display labels only, not selection units.

## Locked decisions (all forks resolved)

Tier table (packages):
- p1: git zsh tmux fzf bat fd ripgrep eza sd fastmod gh
- p2: neovim ranger pipx broot rmem git-fame autopep8 black mdtoc docker meld
      lldb yt-dlp ffmpeg pandoc glow gitui lazygit git-delta
- p3: mpv syncthing obsidian typora copyq zathura zathura-pdf-mupdf okular feh
      skim pngpaste mousepad xsel xclip wl-clipboard
- p4: texlive megasync noto-fonts-emoji noto-fonts-cjk libxft-bgra luarocks

Step priorities (# prio: header):
- p1: 00-homebrew 01-xcode-clt 02-paru 10-rustup 20-oh-my-zsh 80-tpm
      (+ new 61-opencode 62-claude-code)
- p2: 30-ranger-devicons 60-cht-sh 70-volta 90-pyenv 95-pnpm
- p3: 40-wallpapers 50-alacritty-themes 98-macos-defaults

Syntax: bare `pN` token per package line; unlabeled => p4 (safe default).
`--priority p1[,p2]` flag: restrict menu + autoselect (like --all scoped),
skips picker, composes with -y; overrides --all; composes with --group.
Picker labels show `[pN]` so typing "p1" filters in fzf. --list gains column.
Rustup auto-promote: if cargo batch has pkgs and cargo missing, run
10-rustup.sh first (fresh-box p1 story).
link-files: picker shown when interactive (tty, no --dry-run/--yes/pattern);
starts all-selected (start:select-all, fzf>=0.48); ctrl-a selects all matches,
ctrl-d deselects all; selection persists across queries; fallback menu
empty=all, "n"=none, "a"=all, numbers/ranges. Pattern arg still skips picker.

## Scope change (post-approval, folded in)

User: "let's also replace the .mjs script with bash script so our scripts should
[not] rely on a [node] dependency and should run normally on regular fresh unix
systems."

Facts: `list-files.mjs` (88 lines, Node) is called ONLY by link-files.bash:119
(`node "$LISTER" "$1" . ${ignores...}`). Semantics: walk tree from root; regular
files -> emit relpath; dirs -> recurse; symlinks -> stderr warn + skip; other
types -> error exit 1 (we improve: silently skip, no hard fail); `!`-prefixed
input patterns = ignores; ignore matches exact relpath or any path under an
existing directory entry (`bin/.github` excludes subtree). Output unsorted.
link-ignore.txt entries are relative to each root. README does not reference the
mjs. node otherwise appears only in setup/steps/70-volta.sh (unrelated).

Replacement (bash 3.2 compatible, POSIX find/sed/awk/sort only):
- rewrite `list_root()` in link-files.bash: `find "$root" -type f` ->
  awk strips root prefix, drops `!`-prefixed relpaths (parity), drops paths
  equal-to or under ignore entries (string compare: `rel == i ||
  index(rel, i "/") == 1`), sort, re-prefix root; symlinks -> stderr warn.
  Ignores passed via temp file (NR==FNR) with trailing-slash/`./` normalized.
- delete `list-files.mjs` (git rm), drop LISTER var.
- README "What gets linked": note linking no longer needs node.
- QA: capture `link-files.bash --dry-run` baseline BEFORE rewrite, compare
  sorted relpath sets after (identical), plus `bash -n`.

New component 5: replace node lister with bash lister in link-files.bash.
Files: link-files.bash, list-files.mjs (del), README.md.

## Metis record

Metis subagent delegation aborted twice by the harness (ses_00a288fd8ffeDmh4YRjHW7TxtA);
no findings were returned. Gap analysis performed inline instead (full repo
context available). Findings folded into the design:
1. fzf `start` event is unknown pre-0.48 and would make fzf ERROR on old
   installs -> version probe (fzf_ge 0.48), omit binding below; README note.
2. rustup auto-promote would double-run: steps-last loop re-runs all PICKED
   steps without step_done re-check -> after promoting, drop 10-rustup.sh from
   PICKED via awk filter on $4.
3. --priority semantics = mirror --all scoped to tiers (installed entries kept;
   managers no-op) — documented in help; --priority overrides --all.
4. --priority with zero matches -> die with clear message.
5. mjs parity: keep `!`-prefixed relpath skip + symlink stderr warning; unknown
   file types silently skipped (improvement over mjs error-exit-1).
6. ignore entries normalized (strip leading ./ and trailing /) before matching.
7. menu_fallback group-header parse `%%]*}` still correct with `[p1]` in label
   (verified: strips at first `]`).
8. macOS fresh box: setup-os already dies without brew (pre-existing, unchanged).
9. bash 3.2: no `<<<`, no `sort -V` (numeric fzf version compare via process
   substitution + read), no `find -mindepth` (unneeded — -type f never emits the
   root dir).
10. Lister baseline must be captured BEFORE editing link-files.bash (process
    ordering in T7).
11. --list PRIORITY column between ID and MANAGER; width %-6s.
12. README + packages.list header comment both document the pN token.

## Approval gate

status: approved (plan file written + verified; awaiting $start-work)
pending-action: (none — plan complete) execution begins on explicit "$start-work"
approach: 8 files — packages.list relabel; setup-os resolver+flag+picker+
  list+rustup promote; 2 new steps; prio headers on 14 steps; link-files
  picker + bash lister (mjs deleted); README. 9 commits (one per todo, 5
  waves). QA: bash -n, --list/--dry-run/--priority runs, sourced
  expand_selection unit check, tmux-driven interactive picker QA, lister
  baseline-diff.
note: .omo/plans/os-setup-customization.md rewritten in ASD-STE100 (2026-08);
  structure verified: 9 todos + F1-F4 present once each, awk code block in
  todo 7 intact, file ends at Success criteria item 5. All decisions + Momus
  fixes retained. Draft and plan are in sync; no further planning steps
  remain.
