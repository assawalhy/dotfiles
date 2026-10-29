# Plan: make AppImage `--appimage-extract` work under NixOS binfmt (fixes Orca CLI registration)

**Status: implemented, awaiting the switch.** Drafted and executed 2026-10-21.
Progress is in [TODO.md](TODO.md).

## Goal

Fix this Orca error when registering the CLI (which is what the orchestration skill
install hits):

```
cli:install: Could not extract the Orca AppImage at
/home/assawalhy/Applications/orca-linux.AppImage. Check that it is executable and
that /home/assawalhy/.cache/orca/appimage has free space.
```

The message is wrong about both hints. The file is executable and `~/.cache` has
154 GB free (26% inode use). The real cause is the NixOS binfmt layer.

## Findings (verified 2026-10-21)

1. Orca extracts its own AppImage to register the CLI:
   `resources/app.asar.unpacked/out/main/chunks/appimage-registration-lock-CHMcrGsd.js`
   runs

   ```js
   runProcess({ program: nice, args: ['-n','19', appImagePath, '--appimage-extract'],
                cwd: <cache>/<namespace>/<generation>/.extract-XXXX, timeoutMs: 300000 })
   ```

   then requires `<cwd>/squashfs-root/resources/bin/orca-ide`. The same helper is
   used by the background update unpacking (`[appimage-copy] ... keep the mount
   fallback`), so both paths are broken on this host today.

2. On this host every execution of an AppImage is intercepted by binfmt_misc:
   `/proc/sys/fs/binfmt_misc/appimage_type_2` maps
   `7f454c46....414902` to `/run/binfmt/appimage_type_2`, which is
   `appimage-run` from `programs.appimage.binfmt = true` (`nix/configuration.nix:772-778`).

3. That interpreter is `appimage-exec.sh`, which has no `--appimage-extract`
   handling at all: `apprun()` computes `APPDIR=~/.cache/appimage-run/<sha256>`,
   unpacks with `unsquashfs` on first use, echoes `... is now installed in ...`,
   then `exec "$APPDIR/AppRun" "$@"`. Every argument is forwarded to the app.

4. Consequence, reproduced: `orca-linux.AppImage --appimage-extract` prints
   `orca-linux.AppImage installed in ~/.cache/appimage-run/ccd129...` and then
   `[single-instance] Another Orca instance is already running`, exit 3. The temp
   dir stays empty, `squashfs-root` never appears, `ensureLinuxAppImagePayload()`
   returns null, `install()` throws the reported error.

5. `sha256sum orca-linux.AppImage` = `ccd1292210dc2e...`, which is exactly the
   `~/.cache/appimage-run` entry, so the payload is extracted and Orca does run
   from there. Only the `--appimage-extract` contract is broken.

6. `~/.cache/orca/appimage` holds only `launcher/orca-ide` (12 KB, the stable
   launcher). `~/.local/bin/orca` does not exist. Registration therefore only
   leaves the runtime-bound shim `~/.config/orca/linux-orca-cli-shim/orca`,
   which works while PID 2143411 lives and dies with it.

7. Payload offset for the current AppImage: `readelf -h` gives
   `e_shoff 942712 + 64 * 30 = 944632`; `unsquashfs -o 944632 -l` lists
   `squashfs-root/AppRun` correctly. nixpkgs uses the same computation.

## Decision

Register a custom binfmt interpreter, `appimage-binfmt`, that:

- on `<appimage> --appimage-extract` computes the payload offset, runs
  `unsquashfs -q -d "$PWD/squashfs-root" -o <offset> <appimage>`, and exits with
  `unsquashfs`'s status;
- on `<appimage> --appimage-offset` prints the offset (the stock runtime does
  this, `appimage-run` does not);
- otherwise `exec appimage-run "$@"`, byte for byte today's behaviour.

`programs.appimage.binfmt` becomes `false`; the same two registrations (magic
`\x7fELF....AI\x01` / `\x02`, mask `\xff\xff\xff\xff\x00\x00\x00\x00\xff\xff\xff`,
offset 0) are declared in `boot.binfmt.registrations`, type 2 through the wrapper
and type 1 kept on plain `appimage-run`.

### Rejected alternatives

- **Turn binfmt off and run the AppImage directly.** The desktop entry and Orca's
  post-update relaunch both execute the AppImage path itself. Whether that path
  works on NixOS (runtime mount through FUSE, host `/usr/lib` tree) cannot be
  tested while binfmt intercepts it, and it would change how every AppImage in
  `~/Applications` starts. The wrapper changes only the extract branch.
- **Pre-seed `~/.cache/orca/appimage/<namespace>/<generation>`** from the
  `appimage-run` copy. The generation key is
  `sha256(dev\0ino\0size\0mtimeMs)`, so it changes on every Orca release, which is
  exactly when registration runs again. Stopgap only.
- **Leave it and depend on the runtime shim.** The shim is pinned to
  `dev:ino:size:mtime` of the current runtime dir and dies with that PID, so the
  `orca` command stops working after any update or restart.
- **Package Orca in the Nix store.** Kills the in-app updater the user chose
  deliberately (plan 39).
- **Report upstream.** Nothing to fix in Orca: the file is a valid type 2
  AppImage, and the stock runtime answers `--appimage-extract`. The conflict is
  with NixOS's binfmt shim.

## Changes

1. `nix/appimage-binfmt.sh` (new): the interpreter, with a comment explaining the
   contract and why `appimage-run` does not provide it.
2. `nix/configuration.nix`:
   - add `appimage-binfmt = pkgs.writeShellApplication { runtimeInputs = [ appimage-run binutils squashfsTools ]; ... }`
     to the existing top-level `let`;
   - `programs.appimage.binfmt = false;`
   - add `boot.binfmt.registrations.appimage_type_1` and `appimage_type_2`;
   - rewrite the comment at line 772 to state the real constraint.

No change to `common/.local/share/applications/orca-ide.desktop`: the entry keeps
execing the AppImage, which keeps going through binfmt.

## Verification

1. `bash -n nix/appimage-binfmt.sh` passes.
2. Direct runs, same argv shape binfmt uses:
   - `--appimage-offset` prints `944632`;
   - `--appimage-extract` in a temp dir creates the full `squashfs-root` in about
     a second, and `squashfs-root/resources/bin/orca-ide` is byte-identical to the
     copy `appimage-run` made (`sha256 3700b10e...`), mode 0755;
   - `--appimage-extract <pattern>` is refused with exit 2 and no output dir;
   - any other argv reaches `appimage-run` unchanged (checked with a stub on
     `PATH`, because a real launch would hit the single-instance guard).
3. The wrapper derivation builds through `writeShellApplication`, so shellcheck
   passes, and the built `/nix/store/...-appimage-binfmt/bin/appimage-binfmt`
   repeats the two checks above with its own `runtimeInputs` PATH.
4. Full system evaluation and toplevel build from a copy of `nix/` plus
   `/etc/nixos/hardware-configuration.nix` (queued through ajq). The evaluated
   registrations are exactly the old magic and mask pointing at
   `/nix/store/...-appimage-binfmt/bin/appimage-binfmt` (type 2) and
   `appimage-run` (type 1), and the generated `binfmt.d/nixos.conf` matches the
   kernel registration that is live today. `nix/update-nixos.sh build` also syncs
   to `/etc/nixos`, which needs sudo, so the toplevel was built directly with
   `nix-build '<nixpkgs/nixos>' --arg configuration <copy> -A config.system.build.toplevel`.
5. User step (sudo not available in this session): `nix/update-nixos.sh switch`.
   If `/proc/sys/fs/binfmt_misc/appimage_type_2` still names `appimage-run`,
   the old entry survived the restart: `sudo systemctl restart systemd-binfmt`,
   or reboot, then check again.
6. After the switch: `cat /proc/sys/fs/binfmt_misc/appimage_type_2` shows the
   wrapper; the extract test in step 2 still passes; Orca starts from the app grid.
7. Quit Orca fully (window and the `daemon-v48` process), relaunch, register the
   CLI again. Expect `~/.local/bin/orca` and `orca --version` in a plain shell.
8. Confirm the old errors are gone in `~/.config/orca/logs` (`Could not extract`,
   `[appimage-copy] Could not unpack`).

## Risks

- The wrapper is system-wide: any AppImage's `--appimage-extract` now really
  extracts instead of launching the app. That matches upstream AppImage
  behaviour, and it is the intended change.
- Only the no-pattern form is supported (`--appimage-extract <pattern>` is not
  handled by upstream's own multi-arg semantics here). Orca passes no pattern.
  Anything else falls through to `appimage-run`, unchanged.
- Each Orca release leaves an extra ~700 MB under `~/.cache/orca/appimage`.
  Current free space is 154 GB. Pruning old generations is a separate, optional
  cleanup that this plan does not do.
- `~/.cache/appimage-run` held 5 generations (3.4 GB). Three were unused and are
  removed; `ccd129...` is the current app and `033e947...` is held by the
  pre-update daemon, so both stay. `033e947...` becomes removable once Orca is
  restarted.
- `writeShellApplication` runs shellcheck at build time, so a lint error fails the
  build rather than shipping a broken interpreter. It also adds `binutils` to the
  system closure for `readelf`, the same tool nixpkgs' `appimage-exec.sh` uses to
  find the offset.

## Answered

1. Approach approved on 2026-10-21, no trial of the no-binfmt variant.
2. Old cache generations: pruned, see the risk list above.
