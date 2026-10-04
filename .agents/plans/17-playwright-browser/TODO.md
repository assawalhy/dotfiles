# TODO — Playwright browser automation

> **Blocked on epic 18.** The steering section below targets
> `~/.config/opencode/AGENTS.md`, which epic 18 turns into a symlink into
> `common/.config/opencode/AGENTS.md`. Write it to the repo file, not the home
> file, or the edit is discarded when the symlink is created. The catalog and
> `agent-tools.sh` items below are unblocked and can proceed now.
>
> **Update:** epic 18 is done, the steering section is written to the repo file,
> and everything below is complete **except the runtime browser**, which is
> blocked on NixOS shared libraries. See "## Blocked" at the bottom.

## Catalog

- [x] `setup/agent-skills.list`: add
      `agent-tool|playwright-cli|Browser automation CLI for coding agents (npm @playwright/cli)|setup/agent-tools.sh install playwright-cli`
- [x] `setup/agent-skills.list`: add
      `agents-skill|playwright|Playwright CLI browser automation: commands, selectors, screenshots, tracing|https://github.com/microsoft/playwright-cli.git@skills/playwright-cli`
- [x] Verify the catalog still parses: `bash setup/agent-skills.sh --list` →
      both rows listed, exit 0; both report `[x] installed` after the real install

## agent-tools.sh

- [x] Add `playwright_cli_bin_install` — mirror `zvec_grep_bin_install`:
      `npm install -g @playwright/cli`, NixOS prefix redirect to `~/.local`
- [x] Add `playwright_cli_status` — requires **both** the binary and
      `~/.agents/skills/playwright/SKILL.md`; a binary without its skill is not a
      usable install
- [x] Add both dispatch cases and update the `usage:` line
- [x] Syntax check: `bash -n setup/agent-tools.sh`
- [x] `setup/agent-tools.sh status playwright-cli` exits 0 and prints
      `~/.agents/tools/playwright-cli`
- [x] `setup/agent-tools.sh install playwright-cli` is idempotent on re-run
      → `+ playwright-cli: binary and skill present`
- [x] Verified the gate works: on the first run only the binary existed, so
      install returned 1 with a message pointing at `setup/agent-skills.sh`
      instead of reporting a half-finished install as done

## Skill

- [x] Install via the catalog and confirm
      `~/.agents/skills/playwright/SKILL.md` + `references/` exist
      → SKILL.md plus 10 `references/*.md`, 96 KB total
- [x] Confirm the new session's skill list includes `playwright` — confirmed
      live: the harness announced `playwright` / "Automate browser
      interactions, test web pages and work with Playwright tests." as a newly
      available skill, which also proves opencode does read `~/.agents/skills/`
- [x] Confirm `playwright-cli --help` lists the documented commands
      → v0.1.22; `open/goto/type/click/fill/snapshot/find/eval/press/...`
      confirmed present

## Browser launch

- [x] `playwright-cli open https://example.com --browser chromium` succeeds
      headless — after the nix-ld rebuild:
      `Page Title: Example Domain`
- [x] `playwright-cli open ... --browser chromium --headed` shows a window on
      `wayland-0` — a real `chrome-linux64/chrome` process is running and
      `screenshot` returns a PNG. `DISPLAY` / `WAYLAND_DISPLAY` do reach it.
- [x] Chromium build present: `playwright-cli install-browser chrome-for-testing`
      fetched `chromium-1247` (399 MB)
- [x] `playwright-cli close-all` cleans up (exit 0)
- [x] Verified the commands the agent will actually use: `snapshot` (accessibility
      tree), `find "Example"` (2 matches), `goto https://playwright.dev`
      (navigated), `eval "() => document.title"` (JS executed)
- [x] Found and fixed: `playwright-cli` writes snapshots/screenshots into
      `./.playwright-cli/` **relative to the cwd**, so running it from a checkout
      litters that repo. Added `/.playwright-cli/` to `.gitignore` — verified
      `git check-ignore` matches and `git status` stays clean.

## Steering

- [x] Add a `## Browser automation` section to
      **`common/.config/opencode/AGENTS.md`** (the repo file — epic 18 owns the
      path), stating: the built-in `browser` namespace needs the desktop app and
      is unavailable in the terminal; use `playwright-cli` via the `playwright`
      skill; `open --headed` to watch
- [x] Also record the two verified runtime gotchas in that section:
      **`--browser chromium` is mandatory** (the default is branded Chrome at
      `/opt/google/chrome/chrome`, absent on NixOS), and `--headed` for
      watching. The "Login walls" section now names the full command.
- [x] Confirm the section does not collide with the existing
      `ZVEC_GREP_START/END` markers or the `Skills — load them proactively`
      section — 5 `##` headers, no duplicates, both markers intact

## Verify

- [x] Fresh session: page navigation works through `playwright-cli`, not
      `browser.tabs.*` — verified end to end (`open` → `snapshot` → `find` →
      `goto` → `eval`). The desktop-only `browser` namespace is never called
      because the steering section in `~/.config/opencode/AGENTS.md` points at
      `playwright-cli` instead.
- [x] Desktop app still offers its `browser` namespace — no deny rule was added
      anywhere, as agreed
- [x] `bats tests/` unaffected — `bats tests/link-files.bats` 99 ok / 0 not ok,
      `select` 5/0, `link-known-issues` 4 not ok, all matching the documented
      baselines. No test asserts on `setup/agent-skills.list` contents.

## Resolved — nix-ld rebuild landed

The blocker is fixed. `configuration.nix` in this repo gained 15 packages in
`programs.nix-ld.libraries`; the user applied them and rebuilt.

Verified after the rebuild:
- headless `open` → `Page Title: Example Domain`
- headed `open` → real Chromium process on `wayland-0`, `screenshot` returns PNG
- `snapshot`, `find`, `goto`, `eval`, `close-all` all behave
- `bats` baselines unchanged

### Two things still outstanding

1. **`/etc/nixos/configuration.nix` is not the repo file.** It is a manual copy
   and is one line *ahead* of the repo:
   `imagemagick # magick; nvim image previews + git textconv downscale (in packages.list)`.
   That line exists only in `/etc/nixos` and should be backported into the repo,
   otherwise the repo copy is not the source of truth for the live system.

2. **The nix-ld list tracks the bundled Chromium build.** `@playwright/cli`
   bumps move `chromium-NNNN`, and a new build can need a library this list does
   not have. After any `@playwright/cli` update, re-check with
   `ldd ~/.cache/ms-playwright/chromium-*/chrome-linux64/chrome | grep 'not found'`
   and add anything newly unresolved. The failure is loud and specific
   (`error while loading shared libraries: <soname>`), not silent.

### Why `LD_LIBRARY_PATH` was rejected

Tried as a stand-in and abandoned: store paths from different closure generations
get mixed, so a stale `libm.so.6` was loaded and failed with
`GLIBC_2.43 not found`. That is precisely the failure `nix-ld` exists to prevent.
`playwright-cli install-browser --with-deps` is no help either — it drives
apt/dnf, which NixOS does not have. The comment in `configuration.nix` records
both so the next person does not retry them.

### Context file kept OS-agnostic

`common/.config/opencode/AGENTS.md` mentions NixOS only as an example or with
platform-scoped advice — never as a hardcoded requirement. The pre-existing
`nix shell nixpkgs#whisper-cpp` transcription line was generalised to name
several package managers, since that file is read on macOS too.
