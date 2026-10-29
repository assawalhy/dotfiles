# Plan: herdr-ports plugin, popup on `prefix+p`

**Status: implemented, awaiting the user's popup check.** Drafted, approved and
executed 2026-10-21.
Progress is in [TODO.md](TODO.md).

## Goal

Install the `Numbered-com/herdr-ports` plugin so every Space running a TCP listener
shows a `$ports` badge, and open its kill popup with `prefix+p`.

## Findings (verified 2026-10-21)

1. `herdr-ports` is a herdr plugin, not a nix package: `herdr-plugin.toml` declares
   `id = "numbered.ports"`, version 0.7.0, `min_herdr_version = "0.7.4"`. The
   installed herdr is 0.9.1, so the floor is met. Install command:
   `herdr plugin install Numbered-com/herdr-ports`.
2. The manifest supplies the popup pane (`entrypoint main`, placement popup,
   140x24) and the action `open` with `contexts = ["workspace"]`, plus a
   `pane.created` event hook that starts the watcher. Plugins cannot inject
   sidebar rows or keybindings in plugin v1, so both are `config.toml` changes.
3. `prefix+p` is herdr's default `previous_tab` binding, from the default config
   the binary ships (`# previous_tab = "prefix+p"`). Nothing in this repo's
   `common/.config/herdr/config.toml` uses `prefix+p` today; it binds `prefix+a`
   (stay-awake settings) and `prefix+R` (auto-title restart).
4. Requirements are `jq` plus one socket lister. `jq` and `ss` are on PATH;
   `netstat` and `lsof` are not, which is the expected Linux case.
5. A candidate config with `[ui.sidebar.spaces] rows = [["state_icon",
   "workspace", "$ports"], ["branch", "git_status", "$portlist"]]`,
   `previous_tab = "prefix+["` and a `plugin_action` for the not-yet-installed
   `numbered.ports.open` passes `herdr config check` with `config: ok`.
6. The default space rows are `[["state_icon", "workspace"], ["branch",
   "git_status"]]`, so the new rows keep today's layout and add the two tokens.
   `herdr` drops a token that has no value, so Spaces without a listener look
   unchanged.
7. `~/.config/herdr/config.toml` is a symlink to the repo file, so editing the
   repo file is the live edit; only `herdr server reload-config` is needed.
8. Repo convention: herdr plugins are installed by `setup/steps`, currently three
   separate files: `63-herdr.sh` (the binary), `64-herdr-auto-title.sh` and
   `65-herdr-stay-awake.sh`. `.config/herdr/plugins/` is already in
   `link-ignore.txt`, so plugin sources and runtime state stay out of the audit.

## Decision

- **D1 merge herdr and its plugins into one step** (user feedback on the first
  draft, 2026-10-21). `setup/steps/63-herdr.sh` becomes the single herdr step: it
  installs the binary when missing, then `kryptamine/herdr-auto-title`,
  `assawalhy/herdr-stay-awake` and `Numbered-com/herdr-ports`, each skipped when
  `herdr plugin list` already reports it. `64-herdr-auto-title.sh` and
  `65-herdr-stay-awake.sh` are deleted. No `--ref` anywhere, so herdr records
  the commit in `.plugins.lock`, matching today's behaviour.
  - The merged `# check:` names all three plugin ids plus `command -v herdr`, so
    a machine with herdr but missing plugins still offers the step.
  - The Go requirement of auto-title becomes non-fatal: without Go the step
    prints a skip line and installs the other two, and the check keeps the step
    offered so a later run with Go retries it.
  - The stay-awake settings seeding moves into the same step unchanged.
- **D2 popup on `prefix+p`.** `[[keys.command]]` with `key = "prefix+p"`,
  `type = "plugin_action"`, `command = "numbered.ports.open"`,
  `description = "ports popup"`.
- **D3 move `previous_tab` to `prefix+[`.** Overriding `prefix+p` would otherwise
  drop tab back-navigation. `prefix+[` is free and accepted by
  `herdr config check`; `next_tab` stays `prefix+n`.
- **D4 badge rows in `config.toml`.** `$ports` on the workspace row, `$portlist`
  on the branch row so the port list costs no extra line.
- **D5 no `link-ignore.txt` addition.** `.config/herdr/plugins/` already covers
  the plugin sources, its state and its config. The comment above that entry
  gains the merged step's name so the list stays accurate.

### Rejected alternatives

- **`prefix+a`, the plugin README's example.** Taken by the stay-awake settings
  popup.
- **Leave `previous_tab` unbound.** Loses a working binding instead of moving it;
  one config line keeps it.
- **Keep the plugins in their own steps and add a fourth.** Three picker rows for
  one tool, and three files to touch for one upgrade path; the user asked for one
  step.
- **Package the plugin in the Nix store.** It is a herdr plugin, not a Linux
  package: herdr builds and enables it from its own clone, and the other two
  plugins already install this way.
- **Commit the plugin's own configuration.** It has none; its knobs are
  environment variables (`HERDR_PORTS_REFRESH`, `HERDR_PORTS_BADGE`, and others).

## Changes

1. `setup/steps/63-herdr.sh`: extended into the single herdr step.
2. `setup/steps/64-herdr-auto-title.sh`, `setup/steps/65-herdr-stay-awake.sh`:
   deleted.
3. `common/.config/herdr/config.toml`: `[ui.sidebar.spaces] rows`,
   `[keys] previous_tab`, and the new `[[keys.command]]` block.
4. `link-ignore.txt`: name the merged step in the existing herdr comment.

## Verification

1. `bash -n setup/steps/63-herdr.sh` passes.
2. `herdr config check` on the live config after the edit: `config: ok`.
3. `setup-os --list --show-installed` lists one herdr step, and it reports
   installed once all three plugins are present.
4. `herdr plugin install Numbered-com/herdr-ports --yes`, then
   `herdr plugin list` shows `numbered.ports` enabled.
5. `herdr plugin action list` includes `numbered.ports.open`.
6. `herdr server reload-config` succeeds.
7. The installed plugin's own CLI prints a table:
   `~/.config/herdr/plugins/github/Numbered-com.herdr-ports-*/herdr-ports list`.
8. User check: `prefix+p` opens the Ports popup, and a Space running a dev server
   shows the badge and its port list.

## Risks

- `prefix+p` stops switching to the previous tab; the function moves to
  `prefix+[`. Say so now if that key is unwelcome and another free key is picked.
- The popup kills processes: `enter` sends TERM to the checked rows, then KILL.
  That is the plugin's purpose, and it is the reason to keep the badge rows
  visible while using it.
- The badge comes from the watcher, a per-session singleton started by
  `pane.created`, and from workspace metadata with a TTL. After the install the
  badge appears once a new pane is created, not retroactively.
- The plugin is third-party and small (7 stars, one open issue). Its install is
  unpinned, so a reinstall follows upstream HEAD, same as the other two plugins.
