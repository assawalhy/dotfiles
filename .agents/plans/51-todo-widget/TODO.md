# TODO: Todo Widget GNOME extension

- [x] Write `nix/todo-widget.nix` (fetchFromGitHub `0d36c73`, unzip, schemas)
- [x] Wire it: `let` binding, systemPackages, enabled-extensions
- [x] Build the package standalone (`nix-build`)
- [x] Deploy: `nix/update-nixos.sh switch`
- [x] Confirm load: nested shell reports ACTIVE, schema resolves, `~/todo.txt`
      created (the running session cannot rescan; it loads on next login)
- [ ] After a re-login: widget visible on the wallpaper, clicks work,
      `journalctl -b --user-unit` free of `[TodoWidget]` errors
- [ ] Commit
