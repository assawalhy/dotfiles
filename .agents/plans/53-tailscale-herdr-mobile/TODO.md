# TODO: Tailscale for the Herdr mobile app

- [x] 1. `nix/configuration.nix`: `services.tailscale.enable = true;` beside the openssh line (D1, D2).
- [x] 2. `setup/packages.list`: `tailscale` entry in `[extra]` (D4).
- [x] 3. Preview the sync with `nix/update-nixos.sh -n`.
- [x] 4. Build with `nix/update-nixos.sh build`.
- [x] 5. `nix/configuration.nix`: `PasswordAuthentication = false` and `KbdInteractiveAuthentication = false` (D6).
- [x] 6. Build with `nix/update-nixos.sh build` and confirm the generated `sshd_config` says `no`.
- [x] 7. Precondition: `RunSSH` is true (`tailscale set --ssh` at 15:21). The ACL `ssh` rule is still unconfirmed.
- [x] 8. Switch with `nix/update-nixos.sh`. New generation at 15:32; live `/etc/ssh/sshd_config` now has `PasswordAuthentication no` and `KbdInteractiveAuthentication no`, sshd restarted at 15:32:02.
- [ ] 9. Phone check after the switch: reopen the Herdr app, reconnect to `100.65.62.49`, run `hc ls`. This proves whether Tailscale SSH or the `herdr-mobile` key serves the app.
- [ ] 10. ACL tightening (pasted by the user in the admin console): `grants` for `tcp:22` and `icmp`, plus the `ssh` accept rule for `dst: ["autogroup:self"]`.
