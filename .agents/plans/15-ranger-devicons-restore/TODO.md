# TODO — restore ranger devicons

- [x] `setup/steps/30-ranger-devicons.sh`: gate on `__init__.py`, idempotent
      (`pull --ff-only` / wipe-and-clone stale dir)
- [x] `bash -n setup/steps/30-ranger-devicons.sh` clean
- [x] run the step → `~/.config/ranger/plugins/ranger_devicons/__init__.py` exists
- [x] re-run the step (idempotency, no re-clone, rc=0)
- [x] verify against the real store ranger package: import registers `devicons`
      in `FileSystemObject.linemode_dict`
- [x] user: restart ranger, icons visible (visual check only they can do)

## Verification log
- step re-run: `Already up to date.` rc=0 (no re-clone)
- real ranger `qrjq4yd…` load loop (mirrors `core/main.py:446-489`): detected
  `['ranger_devicons']`, imported from
  `~/.config/ranger/plugins/ranger_devicons/__init__.py`, `devicons` in
  `FileSystemObject.linemode_dict`
- `filetitle()` end-to-end on real paths: `rc.conf -> \ue615 rc.conf`,
  `common -> \ue612 common` (devicon PUA codepoints, covered by
  JetBrainsMono Nerd Font in WezTerm)
- setup step hardens the `-d` gate that caused the silent skip
- user confirmed in a live ranger session: icons render