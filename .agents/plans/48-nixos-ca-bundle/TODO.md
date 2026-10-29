# TODO: /etc/ssl/cert.pem for uv Pythons

- [x] 1. `nix/configuration.nix`: add
      `environment.etc."ssl/cert.pem".source = config.security.pki.caBundle;`
      with the one-line reason comment; `nix-instantiate --parse` clean.
- [x] 2. `nix/update-nixos.sh` — sync `nix/` to `/etc/nixos`, then
      `sudo nixos-rebuild switch`.
- [x] 3. Verify: `/etc/ssl/cert.pem` resolves into the store; the rv python
      reports 172 loaded roots with no `SSL_CERT_FILE`; `env -u SSL_CERT_FILE
      rv auth` provisions a key.
- [x] 4. `common/.config/mise/config.toml`: add `uv = "latest"` with the reason
      comment; `nix/configuration.nix`: extend the `uv` comment to say nix's
      copy is the non-interactive fallback.
- [x] 5. `mise install`; confirm `mise ls uv` resolves 0.13.6.
- [x] 6. Verify: login-shell `uv --version` is 0.13.6 while
      `${pkgs.uv}/bin/uv --version` stays 0.11.21; `uv tool list` still sees
      rv and harbor; `uv python list` finds the existing installs.
- [x] 7. Commit the `nix/` + `common/` changes in dotfiles.

Verified 2026-10-29: `/etc/ssl/cert.pem` links into the store, the rv Python loads 172 roots, and `env -u SSL_CERT_FILE rv auth` passes TLS. It then answers 409 "A key already exists until 2026-11-05", because the key was provisioned earlier with `SSL_CERT_FILE` set. `mise ls uv` resolves 0.13.6, `/run/current-system/sw/bin/uv` stays 0.11.21, and `uv tool list` still shows rv.
