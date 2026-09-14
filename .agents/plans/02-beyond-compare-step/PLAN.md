# Plan: Beyond Compare install step

## Goal
Make Beyond Compare installable from `setup-os` on every platform the Scooter
Software KB (linux_install) covers: Debian/Ubuntu, RHEL/Fedora, openSUSE, Arch,
and macOS.
https://www.scootersoftware.com/kb/linux_install

## Approach
One step script `setup/steps/65-beyond-compare.sh` (not a packages.list entry):
- macOS: `brew install --cask beyond-compare`
- apt: add Scooter's repo (key .asc + sources list per KB), then `apt-get install -y bcompare`
- dnf: `rpm --import` key + write `scootersoftware.repo`, then `dnf install -y bcompare`
- zypper: `rpm --import` key + `zypper addrepo`, then install (SUSE is "partially
  supported" upstream: gvfs-smb dep may need --force)
- pacman: install AUR `bcompare` via paru/yay; hint to run 02-paru.sh if neither exists
- Repo setup is guarded so an existing install (e.g. the .deb postinst's
  `scootersoftware.sources`) is never duplicated.

## Decisions
- Step, not packages.list entry: setup-os runs steps **after** the package batch,
  so a repo-prep step could never precede an `apt:bcompare` install.
- Repo-based install, not the KB's pinned `.deb`/`.rpm` download URLs: those embed
  the exact version (5.2.5.32528) and rot; the repo carries updates.
- amd64 precheck on Linux: the deb/rpm repos are amd64-only.
- p3 tier, `check: command -v bcompare`: matches GUI app conventions and hides the
  entry once installed.

## Milestones
1. Script written, shellcheck/bash -n clean
2. Appears correctly in `setup-os --list` / picker
3. Live-run on this Ubuntu box is clean and idempotent
4. Committed

## Risks
- openSUSE branch can't be tested here; kept minimal per KB's "partially supported".
- AUR package is third-party (Musikolo) but tracks releases same-day and is the
  documented community standard.
