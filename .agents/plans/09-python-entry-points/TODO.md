# TODO: python entry points (uv-native)

- [x] 1. Run `uv python install 3 --default` (add `--force` if it refuses the
      existing `python3.14` link); confirm `~/.local/bin/python` and
      `python3` appear. — done: `python`, `python3` → cpython-3.14.6, exit 0.
- [x] 2. Create `setup/steps/91-uv-python.sh` with `# desc:` `# os: any`
      `# check: [ -e "$HOME/.local/bin/python" ]` `# prio: p2`
      `# requires: uv` and body `uv python install 3 --default`;
      `bash -n` clean. — done, +x, `bash -n` OK.
- [x] 3. README: add the python note to the PATH section — python/python3
      come from `uv python install --default` (step 91); pip via
      `uv pip` / `python3 -m pip`. — done, Shell profiles section.
- [x] 4. Verify: `command -v python python3`; `python3 -V`; `python -c`;
      venv creation + active-venv interpreter/pip precedence;
      `setup-os --list` hides step 91 while `~/.local/bin/python` exists;
      `bats tests/link-files.bats` (expect 99 ok, 0 not ok).
      — done: python/python3 → ~/.local/bin (3.14.6); `python -m json.tool`
      ✓; active venv's python/pip win PATH, deactivate restores ✓; guard
      passes `step_done` semantics on this machine (→ picker `(done)`) and
      fails on a fresh HOME (→ offered); `bats link-files` **99 ok / 0 not
      ok**, `bats select` **5 ok**. NB: `--list` prints all resolving
      entries by design (installed-state filtering lives in the picker).
- [x] 5. `configuration.nix`: add `systemd.user.services.uv-python` —
      `wantedBy = [ "default.target" ]`, `Type = "oneshot"`,
      `ConditionPathExists = "!%h/.local/bin/python"`,
      `ExecStart = "${pkgs.uv}/bin/uv python install 3 --default"`;
      `nix-instantiate --parse configuration.nix`. — done, parse OK
      (unit placed before `services.envfs`).
- [ ] 6. Deploy: `diff` repo vs `/etc/nixos/configuration.nix` (local-only
      edits in /etc → stop and ask); back up `/etc/nixos/configuration.nix`,
      copy the repo file over, `sudo nixos-rebuild switch`.
- [ ] 7. Verify: unit present + enabled for the user manager; skip path
      (condition false while links exist); positive path — `rm` the two
      links, `systemctl --user start uv-python`, links restored, journal
      clean; `bats tests/link-files.bats` (99 ok).
