# 35 openssl in the system profile

- [x] Add `openssl` to `environment.systemPackages` in `nix/configuration.nix`
- [x] Verify the file evaluates (`nix-instantiate --parse`, then the rebuild's own eval)
- [x] Run `nix/update-nixos.sh` (sync + switch)
- [x] Verify `command -v openssl`, `openssl version`, one TLS handshake
- [x] Commit the openssl entry on its own, leaving the pending plan-33 and libxi edits unstaged