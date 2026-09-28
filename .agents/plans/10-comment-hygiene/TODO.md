# TODO: comment hygiene

Batches are disjoint; each is one sub-agent reading `PLAN.md` + this item.
Coordinator validates the diff, then ticks.

- [x] A. `link-files.bash`, `tests/link-files.bats`,
      `tests/link-known-issues.bats`, `tests/select.bats`,
      `tests/helpers.bash`, `tests/nvim-smoke.bash` — apply policy; validate
      diff; `bash -n` each file. — done: 136/83/19/15/42/27 kept, 6 deleted,
      59 rewritten; diffs + suites reviewed by coordinator.
- [x] B. `common/bin/setup-os`, `setup/agent-tools.sh`,
      `setup/agent-skills.sh`, `setup/steps/*.sh` — apply policy; validate
      diff; `bash -n` each file. — done: 24 files, narration/labels dropped,
      `# desc/os/check/prio/requires` headers byte-identical, `bash -n` OK.
- [x] C. `configuration.nix`, `common/.bash_profile`, `common/.zshrc`,
      `common/.bashrc`, `linux/.profile`, `linux/.config/shell/os.sh`,
      `macos/.config/shell/os.sh` — apply policy; validate diff;
      `nix-instantiate --parse configuration.nix`. — done: 198 deleted
      (mostly NixOS stock template), keeps verified in place; parse OK,
      `zsh -n` OK (`.zshrc` `bash -n` failure pre-exists at HEAD, zsh-ism).
- [x] D. `common/.config/nvim/**/*.lua`, `common/bin/*` (minus `setup-os` and
      the markdown `README.md`), `linux/bin/*` — apply policy; validate diff;
      `bash -n` the shell scripts. — done: 246→177 comment lines, lua
      `loadfile()` parse 0 failures, dead commented-out code removed
      (keyboard, tmux-yadwy, ydi, arnums), `bash -n` OK.
- [x] 5bis. Coordinator: banned-word rescan over all changed comments —
      clean; 4 `@test` names containing "wins" renamed to "takes
      precedence" (in-plan: style covers test names; only README prose
      references the phrase, and markdown is out of scope).
- [x] 5. Final verification: `bash -n` over every touched shell file,
      `nix-instantiate --parse configuration.nix`,
      `bats tests/link-files.bats` (99 ok / 0 not ok),
      `bats tests/select.bats` (5 ok), `bats tests/link-known-issues.bats`
      (all `not ok` — expected), `tests/nvim-smoke.bash`, and a final
      `git diff --stat` review. — **all green**: bash -n OK (except
      `ytdl-list:76`, identical at HEAD → pre-existing), nix parse OK,
      99/0 · 5/0 · known-issues 4-not-ok-as-designed, nvim-smoke 5/6
      (check 6 fails at HEAD too: `after/ftplugin/java.lua` removed in
      `fabdd18` while the assertion stayed), diff stat 44 files
      +231/−519 (net −288 comment lines), banned-word scan clean.
