# TODO: Proton split tunnel

- [x] 0. Prove WireGuard is blocked and MASQUE works (scratchpad tests, see PLAN.md Evidence).
- [x] 1. `nix/configuration.nix`: `usque` systemd service, socks on 127.0.0.1:1080, config in `/var/lib/usque/config.json` (StateDirectory, DynamicUser off or fixed user).
- [x] 2. Provision `/var/lib/usque/config.json` from the scratchpad `usque/config.json` by hand, mode 600.
- [x] 3. `nix/configuration.nix`: `services.sing-box` with tun inbound, Proton `domain_suffix` rule to the socks outbound, `final = direct`, DNS config that resolves Proton names.
- [x] 4. `setup/packages.list`: usque entry if the file lists tools for non-NixOS hosts. Not needed: usque is declared in nix/configuration.nix only.
- [x] 5. Build with `nix/update-nixos.sh build`. Green.
- [x] 6. Switch with `nix/update-nixos.sh`. Done.
- [x] 7. Verify: curl `proton.me`, `pass.proton.me`, `protonvpn.com` without a proxy flag return 200. proton.me, pass.proton.me, protonvpn.com, account.proton.me, mail.proton.me return 200.
- [x] 8. Verify: a non-Proton site's exit IP is unchanged, `tailscale ping` to the phone still works. GitHub 200, exit IP unchanged (warp=off), Tailscale ping to the phone works.
- [x] 9. Delete the scratchpad WARP profiles (`wgcf` account and `wgproton.conf`). Done.
- [x] 10. Public repo check before any commit: `rg -i 'private_?key|access_token|device_id|wgcf|usque.*config'` over the diff shows no credential, key, account ID or device ID. Only the design, the domain list and `127.0.0.1:1080` may appear. No match in the diff.
