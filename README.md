# My Config Files

As-salamu alaykum. These are my dotfiles for **macOS and Linux**, kept in one
repo and symlinked into `$HOME`.

I used to `git init` in `$HOME` directly, ignoring everything and un-ignoring
the configs. That broke two things: `neovim`'s file manager treats the
directory containing `.git` as the workspace root, so every session rooted at
`$HOME`; and the zsh git plugin showed branch status in every directory,
including `Desktop`. Keeping the files in a repo and linking them out avoids
both.

## Layout

| Directory | Linked when | Contents |
|---|---|---|
| `common/` | always | everything portable — nvim, tmux, git, zsh/bash, mpv, ranger, `bin/` |
| `linux/`  | on Linux | X11 and Arch-specific — `.xinitrc`, `.Xmodmap`, `.profile`, zathura, `bin/arch-scripts/` |
| `macos/`  | on macOS | `.hushlogin`, and the macOS halves of the split configs |

Both `common/` and the overlay for the current OS are linked. **On a path
collision the OS overlay wins**, which is how the platform-specific pieces are
swapped in:

```
common/.bash_profile          -> ~/.bash_profile        (both platforms)
linux/.config/shell/os.sh  ─┐
macos/.config/shell/os.sh  ─┴> ~/.config/shell/os.sh    (whichever OS you're on)
```

`~/.bash_profile` sources `~/.config/shell/os.sh` on its first line, so the
platform-specific aliases, functions and `PATH` entries come from exactly one
file and neither copy needs a `uname` branch. The same trick is used for
`~/.config/git/os.gitconfig`.

## Linking

```sh
git clone <this repo> ~/Projects/dotfiles
~/Projects/dotfiles/link-files.bash
```

It works from any directory, detects the OS itself, shows you exactly what it
will do, and asks before touching anything.

```
USAGE:
  link-files.bash [--help] [--force] [--no-backup] [--dry-run] [--yes] [--refresh] [--audit] [--diff] [--fix] [filtering_pattern]
  link-files.bash --force '.*nvim/lua.*'
  link-files.bash --refresh --dry-run
  link-files.bash --audit
  link-files.bash --diff --dry-run
  link-files.bash --fix --dry-run

OPTIONS:
  -h, --help      show this message and exit
      --force     resolve conflicts: replace foreign symlinks, and back up
                  real files to <file>.bak.<timestamp> before linking
      --no-backup with --force, delete a conflicting real file instead of
                  backing it up to <file>.bak.<timestamp>; refuses to
                  replace a directory; requires --force
      --diff      show a unified diff between the home file and the repo
                  file for each conflict/relink candidate before confirming
  -n, --dry-run   show what would happen, then exit without changing anything
  -y, --yes       skip the confirmation prompt
      --refresh   capture new files that appeared inside linked dirs into the
                  repo (OS overlay first, else common) and symlink them back;
                  never overwrites repo files; --force has no effect; skips
                  files neglected for the current session context
                  (wayland/x11/headless)
      --audit     read-only link-drift report: repo files lacking a correct
                  home link (missing/relink/conflict/stale) plus real files
                  in linked dirs absent from the repo. Excludes files
                  neglected for the current session context
                  (wayland/x11/headless), same as linking. Exit 0 = clean,
                  1 = findings; never writes, no picker, no prompt
      --fix       complete linking: remove stale, ignored and session-neglected
                  links, link missing files, relink and resolve conflicts
                  (implies --force); cannot be combined with --audit or
                  --refresh
  <pattern>       extended regex; only paths matching it are considered
```

```sh
link-files.bash                 # everything
link-files.bash --dry-run       # preview only
link-files.bash '.*nvim/lua.*'  # just the nvim plugin files
link-files.bash --force         # also resolve conflicts
```

### Interactive selection

Run bare, `link-files.bash` opens an interactive picker over the linkable
files that still need linking — anything already linked correctly is left out —
each tagged with a `[group]` label (git, shell, tmux, x11, bin, other).
Type to filter, `TAB` toggles a file, `CTRL-A` selects all current matches and
`CTRL-D` clears the selection. Marks survive when you clear the query, so you
can build a set across several searches. fzf 0.48 and newer starts with everything selected;
older fzf needs a `CTRL-A` first. Without fzf there is a numbered fallback menu
with `a` for all and `n` for none.

The picker only opens when nothing else tells the script what to do: a
`<pattern>` argument, `--dry-run` or `--yes` all skip it, so the invocations
above behave exactly as before. The linker no longer needs node: the path
listing is a bash script now.

### What gets linked

Everything committed under `common/` and the active OS directory — **there is
no include list**. `link-ignore.txt` is the exception list: paths named there
are committed but not linked. `link-context.txt` is the session-context filter
for every link operation: a relpath tagged for another context (like
`x11: .Xmodmap` under wayland) is excluded from linking, listing, `--diff`,
`--refresh` and the audit report.

Adopting a new dotfile is therefore just a move:

```sh
mv ~/.foo common/.foo && ./link-files.bash
```

(This replaces the old `--reverse` flag, which captured files from `$HOME` back
into the repo. With symlinks the repo *is* the live copy, so there is nothing to
capture and the flag is gone.)

### Capturing new files (`--refresh`)

Programs sometimes write new files straight into a linked directory, a plugin
adding its own config, a program creating a state file. Run with `--refresh`
after that and the script picks those files up: anything inside a linked dir
that is not already in the repo, not named in `link-ignore.txt`, and not
matched by gitignore. Each one lands at the same relative path in the repo, in
the OS overlay when that path exists there and in `common/` otherwise, and is
symlinked back so the live file keeps working.

`--refresh` never overwrites a repo file, and `--force` has no effect on it.
New files whose relpath is neglected for the current session context are
skipped, so an x11-only config directory is not scanned for captures while on
a Wayland session.
Like every other mode it previews what it will capture and then asks for the 🔥
confirmation before moving anything. `--dry-run` shows the preview and stops,
`--yes` skips the prompt, and a `<pattern>` narrows the scan.

```sh
link-files.bash --refresh             # capture everything new
link-files.bash --refresh --dry-run   # preview only
link-files.bash --refresh 'extra\.conf$'
```

### Checking the link state (`--audit`)

`--audit` is a read-only report of link drift in both directions: repo files
that are not correctly linked in `$HOME` (missing, pointing at the wrong
source, a conflict, or stale), and real files inside linked dirs that are
absent from the repo. It never writes anything, opens no picker, and asks
nothing. Exit 0 means the links are clean, exit 1 that there are findings.

Some files only belong to particular desktop sessions. `link-context.txt`
lists those, per session context: a line like `x11: .Xmodmap` marks `.Xmodmap`
as x11-only. The filter is applied up front for every operation, so on a
Wayland session `.Xmodmap` is excluded from linking, listing, `--diff`,
`--refresh` and this report alike, and reported only on an X11 session.
`--audit` prints `audit context: <ctx> (neglecting: ...)` in its header,
naming the contexts it excluded. The context is detected from the environment
(wayland, x11, or headless). Stale links to repo files that were deleted are
reported on any session — they are dangling pointers, independent of the
session context.

### Conflicts

Every candidate path falls into one of these:

| Preview | Meaning | Needs `--force`? |
|---|---|---|
| *(silent)* | already the right symlink | — |
| `+` | nothing there yet, will be created | no |
| `*` | an old hard link, or a symlink pointing at the wrong file in this repo | no |
| `-` | a symlink into this repo that is no longer wanted; will be removed | no |
| `~` | a conflict being resolved by `--force` | yes |
| `!` | a conflict — a real file, or a symlink pointing outside this repo | yes |
| `i` | ignored by `link-ignore.txt` but still linked; removed by `--fix` | no |
| `x` | neglected for the current session but still linked; removed by `--fix` | no |

Real files are never deleted. Under `--force` they are moved to
`<file>.bak.<timestamp>` first, unless `--no-backup` is given, which deletes
the real file instead (and refuses directory conflicts).

Add `--diff` to see what you would lose before deciding: it prints a unified
diff of the home file against the repo's for every conflict/relink candidate
that has content on both sides (foreign symlinks are dereferenced), right
before the confirmation prompt. Identical files are marked `(identical)`.
On a terminal the diff is rendered colored through `delta` when it is
installed; otherwise (or when output is piped) plain `diff -u` is used.

Old hard links from the previous scheme are detected by inode, so the migration
to symlinks needs no flags and creates no backups — the content is identical by
definition.

Stale links (`-`) are only ever removed when they point *into this repo*.
Unrelated symlinks in `$HOME` are left alone.

### Completing the link state (`--fix`)

`--fix` is the write counterpart of `--audit`: it completes linking and
prunes what should not be linked. It links missing files, relinks
wrong-source symlinks, resolves conflicts (backing up real files to
`<file>.bak.<timestamp>`), and removes stale links, links ignored by
`link-ignore.txt` (reported as `i [ignored]`) and links neglected for
the current session context (reported as `x [neglected]`). It implies
`--force`, never opens the picker, and cannot be combined with `--audit`
or `--refresh`. `--dry-run` previews every change with the same markers
as a normal run.

```sh
link-files.bash --fix --dry-run   # preview what would change
link-files.bash --fix             # complete linking and prune
```

## Installing programs

```sh
./setup-os              # pick from a list, then install
./setup-os --list       # just show what resolves on this machine
./setup-os --dry-run --all
./setup-os --priority p1 -y     # temp machine: essentials + agents, no prompt
./setup-os --priority p1,p2     # the dev workstation tiers in one run
```

Uses Homebrew on macOS and pacman / apt / dnf / zypper on Linux (plus `paru` or
`yay` for AUR packages, when one is installed). Already-installed entries are
hidden from the picker; `--show-installed` keeps them.

Every entry belongs to a priority tier, `p1` to `p4`:

| Tier | Covers |
|---|---|
| `p1` | SSH essentials and agents: git, zsh, tmux, fzf, bat, fd, ripgrep, eza, sd, fastmod, gh, plus the rustup, oh-my-zsh, tpm, opencode and claude steps |
| `p2` | dev workstation |
| `p3` | GUI |
| `p4` | occasional |

`--priority` selects a tier and skips the picker, so a temp machine is one
command: `./setup-os --priority p1 -y` installs the essentials with no prompt.
The flag is repeatable and comma-separated, so `./setup-os --priority p1,p2`
covers a dev workstation in one run. It also takes precedence over `--all`,
narrowing that to the tiers you named.

Selection uses `fzf --multi` when available and falls back to a numbered menu
otherwise, so it works on a machine where nothing is installed yet. Type a group
name then `Ctrl-A` to select a whole group at once.

- **`setup/packages.list`** — the package table. One logical name per line, with
  per-manager overrides only where the names differ:

  ```
  fd            apt:fd-find  dnf:fd-find    # `fd` everywhere else
  zsh           p1                          # bare pN token = priority tier
  texlive       cask:basictex  pacman:texlive-core
  xclip         !macos                      # X11 only
  megasync      cask:megasync  aur:megasync-bin  pacman:-
  ```

  The bare `pN` token sets the priority tier; it goes at the end of the line,
  before any comment. Lines without one default to `p4`.

- **`setup/steps/*.sh`** — the things that aren't packages (rustup, oh-my-zsh,
  tpm, volta, pnpm, macOS `defaults`, …). One executable file each, with
  `# desc:`, `# os:`, `# check:` and `# prio:` headers so `setup-os` can label
  them, filter them by platform, skip the ones already done, and include each
  one in its priority tier. Each is runnable on its own.

Failures don't abort the run — a batch that fails is retried one package at a
time to isolate the culprit, and everything that failed is listed at the end.

On a fresh box with no cargo, rustup runs automatically right before the cargo
packages, so you don't have to bootstrap it by hand first.

## Caveats

- **Programs that save by write-and-rename replace the symlink with a real
  file.** `git config --global` is the common one: it will turn `~/.gitconfig`
  into a regular file. The next `link-files.bash` reports it as `!`; run with
  `--force` and your edits are preserved in the `.bak` file.
- `common/.config/nvim/lazy-lock.json` is written through to the repo, so plugin
  updates show up as git changes. That's intended — it's how the lockfile stays
  versioned.
- `~/.npmrc` is deliberately not in this repo: it contains a registry
  `_authToken`.
- `common/bin/` is linked to `~/bin` on both platforms, so scripts there must be
  portable. Use `clip` (`clip` to copy, `clip -o` to paste) instead of
  `pbcopy`/`xclip`/`xsel` directly — it picks the backend at runtime, and tmux
  and nvim both go through it. Linux-only scripts belong in `linux/bin/`.

## License

MIT
