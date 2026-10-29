# TODO — herdr-ports

Drafted 2026-10-21, approved the same day. See [PLAN.md](PLAN.md).
Executed 2026-10-21; only the user's popup check is open.

- [x] `setup/steps/63-herdr.sh`: one step for herdr plus the three plugins (D1)
- [x] delete `setup/steps/64-herdr-auto-title.sh` and
      `setup/steps/65-herdr-stay-awake.sh` (D1)
- [x] `common/.config/herdr/config.toml`: add `[ui.sidebar.spaces] rows` with
      `$ports` and `$portlist` (D4)
- [x] `common/.config/herdr/config.toml`: `[keys] previous_tab = "prefix+["` (D3)
- [x] `common/.config/herdr/config.toml`: add the `prefix+p` `plugin_action` for
      `numbered.ports.open` (D2)
- [x] `link-ignore.txt`: name the merged step in the herdr comment (D5)
- [x] `bash -n setup/steps/63-herdr.sh` passes
- [x] `herdr config check` reports `config: ok`
- [x] install the plugin, `herdr plugin list` shows `numbered.ports` enabled
      (commit `1d9f061d7aae0170e598ad478240bd9620b3f034`)
- [x] `herdr plugin action list` includes `numbered.ports.open`
- [x] `herdr server reload-config` applies with no diagnostics
- [x] the plugin's own `herdr-ports list` prints a table (two listeners today)
- [x] `herdr workspace list` shows `tokens.ports` (`↯`) and `tokens.portlist`
      on Spaces with listeners, so the badge rows have live data
- [x] `setup-os --dry-run --all` lists one herdr step, and its `# check:`
      evaluates to 0, so setup-os treats it as done
- [x] user check: `prefix+p` opens the popup, a Space with a listener shows the
      badge and its port list (confirmed 2026-10-22)
