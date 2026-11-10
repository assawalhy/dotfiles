# TODO: Quick Share

- [x] 1. `nix/configuration.nix`: `rquickshare` in `[gui]`, plus `networking.firewall.allowedTCPPorts = [ 12345 ]` and `allowedUDPPorts = [ 5353 ]` (comments naming D2).
- [x] 2. Rebuild with `nix/update-nixos.sh`.
- [x] 3. Write `~/.local/share/dev.mandre.rquickshare/.settings.json`: the app's four defaults plus `"port": 12345` and `"startminimized": true`, since the app has not run in the real `$HOME` yet.
- [x] 4. Launch `rquickshare`, confirm the window and `ss -ltn | grep 12345`.
- [ ] 5. Verify per PLAN.md: phone → PC (`Ministry-of-Commerce-01-1.svg` in `~/Downloads`) and PC → phone both worked on 2026-11-10; the phone showed up in the device list, so #431 does not affect it. Still open: close-and-reopen, and login behaviour after the next log out.
- [x] 6. Commit `nix/configuration.nix` and the plan.
