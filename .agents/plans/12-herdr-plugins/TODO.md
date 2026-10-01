# TODO — herdr plugins (#21)

- [x] epic + comment plan on #21 (plan decisions live in the issue body)
- [x] delete `setup/steps/64-herdr-workspace-manager.sh` + committed workspace-manager config
- [x] new `setup/steps/64-herdr-auto-title.sh` (install + restart action)
- [x] `setup/steps/65-herdr-stay-awake.sh`: seed config.json when missing
- [x] `common/.config/herdr-auto-title/config.env` (tracked, linked)
- [x] `common/.config/herdr/config.toml`: prefix+R auto-title restart
- [x] `link-ignore.txt`: ignore `plugins/` + `herdr-auto-title/manual-names.json`
- [x] `tests/link-files.bats`: au_herdr to the new ignore shape (test green)
- [x] stay-awake installed + config seeded (defaults)
- [x] auto-title installed (first try hit a transient DNS failure on proxy.golang.org)
- [x] link-files --fix --yes (links config.env) + audit herdr-clean + full bats 99 ok / 0 not ok
- [ ] commit + push + PR
