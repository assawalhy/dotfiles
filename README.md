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
  link-files.bash [--help] [--force] [--dry-run] [--yes] [filtering_pattern]

  -h, --help      show the help and exit
      --force     resolve conflicts (see below)
  -n, --dry-run   show what would happen, then exit
  -y, --yes       skip the confirmation prompt
  <pattern>       extended regex; only matching paths are considered
```

```sh
link-files.bash                 # everything
link-files.bash --dry-run       # preview only
link-files.bash '.*nvim/lua.*'  # just the nvim plugin files
link-files.bash --force         # also resolve conflicts
```

### What gets linked

Everything committed under `common/` and the active OS directory — **there is
no include list**. `link-ignore.txt` is the exception list: paths named there
are committed but not linked.

Adopting a new dotfile is therefore just a move:

```sh
mv ~/.foo common/.foo && ./link-files.bash
```

(This replaces the old `--reverse` flag, which captured files from `$HOME` back
into the repo. With symlinks the repo *is* the live copy, so there is nothing to
capture and the flag is gone.)

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

Real files are never deleted. Under `--force` they are moved to
`<file>.bak.<timestamp>` first.

Old hard links from the previous scheme are detected by inode, so the migration
to symlinks needs no flags and creates no backups — the content is identical by
definition.

Stale links (`-`) are only ever removed when they point *into this repo*.
Unrelated symlinks in `$HOME` are left alone.

## Installing programs

```sh
./setup-os              # pick from a list, then install
./setup-os --list       # just show what resolves on this machine
./setup-os --dry-run --all
```

Uses Homebrew on macOS and pacman / apt / dnf / zypper on Linux (plus `paru` or
`yay` for AUR packages, when one is installed). Already-installed entries are
hidden from the picker; `--show-installed` keeps them.

Selection uses `fzf --multi` when available and falls back to a numbered menu
otherwise, so it works on a machine where nothing is installed yet. Type a group
name then `Ctrl-A` to select a whole group at once.

- **`setup/packages.list`** — the package table. One logical name per line, with
  per-manager overrides only where the names differ:

  ```
  fd            apt:fd-find  dnf:fd-find    # `fd` everywhere else
  texlive       cask:basictex  pacman:texlive-core
  xclip         !macos                      # X11 only
  megasync      cask:megasync  aur:megasync-bin  pacman:-
  ```

- **`setup/steps/*.sh`** — the things that aren't packages (rustup, oh-my-zsh,
  tpm, volta, pnpm, macOS `defaults`, …). One executable file each, with
  `# desc:`, `# os:` and `# check:` headers so `setup-os` can label them, filter
  them by platform, and skip the ones already done. Each is runnable on its own.

Failures don't abort the run — a batch that fails is retried one package at a
time to isolate the culprit, and everything that failed is listed at the end.

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
