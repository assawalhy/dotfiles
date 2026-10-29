# Plan: `/etc/ssl/cert.pem` so uv Pythons can do TLS

## Goal

`rv auth` (and every other uv-installed tool) completes HTTPS requests on this
host without `SSL_CERT_FILE` set by hand.

## Symptom (verified 2026-10-29)

```
$ rv auth
Summary: 5/5 checks passed
error cannot reach provisioner: [SSL: CERTIFICATE_VERIFY_FAILED]
      certificate verify failed: unable to get local issuer certificate (_ssl.c:1082)
```

## Root cause

The `rv` shebang runs python-build-standalone (uv's CPython 3.14.6), whose
OpenSSL was compiled with `--openssldir=/etc/ssl` defaults:

```
DefaultVerifyPaths(cafile=None, capath='/etc/ssl/certs',
                   openssl_cafile='/etc/ssl/cert.pem',
                   openssl_capath='/etc/ssl/certs')
```

NixOS ships the CA bundle only as `/etc/ssl/certs/ca-certificates.crt` (plus
`ca-bundle.crt`). There is no `/etc/ssl/cert.pem`, and `/etc/ssl/certs` holds
no hashed symlinks, so `ssl.create_default_context()` loads **0** roots:

```
certs loaded (default): 0
certs loaded (env):     172   # SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt
```

Not an `rv` bug, not a network or proxy problem: `curl` (system bundle) and
`openssl s_client` both verify the provisioner cert fine, and
`SSL_CERT_FILE=... rv auth` provisioned the key successfully.

## What to change

`nix/configuration.nix`, one line next to the existing `services.envfs` /
python block:

```nix
# python-build-standalone (uv's CPython, and every uv tool: rv, harbor, …)
# compiles OpenSSL with the default cafile /etc/ssl/cert.pem, which NixOS
# never creates. Without it ssl.create_default_context() loads zero roots.
environment.etc."ssl/cert.pem".source = config.security.pki.caBundle;
```

`security.pki.caBundle` is the read-only option that already feeds
`/etc/ssl/certs/ca-certificates.crt`, so a custom `security.pki.certificates`
entry stays trusted by the uv Pythons too.

## Decisions

- **Fix the missing path, not the environment** — restoring the compiled-in
  cafile repairs every standalone Python at once, with no env var and no
  per-tool wrapper.
- **`config.security.pki.caBundle`, not `${pkgs.cacert}/...`** — keeps the
  bundle the same one the rest of the system trusts.
- **Deploy through `nix/update-nixos.sh`** — repo is source of truth; the
  script rsyncs `nix/` to `/etc/nixos` and runs `nixos-rebuild switch`.

## Rejected alternatives

| alternative | why not |
|---|---|
| `environment.variables.SSL_CERT_FILE` | Works, but only for processes that inherit it; `env -i`, some systemd units and GUI-launched tools still break. Also a global override that can shadow other bundles. |
| Wrapper script for `rv` that exports `SSL_CERT_FILE` | Fixes one binary. `harbor` and every other uv tool stay broken. |
| Patch `rv/cli/auth.py` to pass `cafile=` | Third-party package under `~/.local/share/uv/tools`; `rv update` overwrites it. |
| `export SSL_CERT_FILE` in the zsh profile | Session-only, misses non-shell processes, and hides the real defect. |

## Milestones

1. Add the `environment.etc` line, parse-check the file.
2. Sync + switch.
3. Prove `rv auth` works with a clean environment.

## Part 2 — latest uv, via mise

`uv` is 0.11.21 (nixpkgs 26.05); upstream is 0.13.6. nixpkgs cannot be bumped
to it without a channel move, so mise owns the floating copy — the same split
node already uses.

```
nix/configuration.nix         uv (0.11.21)  ← systemd unit, setup scripts, GUI
common/.config/mise/config.toml  uv = "latest" (0.13.6)  ← interactive shells
```

- **Keep `uv` in nix.** Unlike `bun` (epic 46 decision 4), uv has consumers
  that never run `mise activate`: `systemd.user.services.uv-python` calls
  `${pkgs.uv}/bin/uv`, and `setup/agent-tools.sh` runs non-interactively.
  Dropping it would break both.
- **`uv = "latest"`, not a pin.** Matches `setup/packages.list` (`uv # PyPI
  latest`) and the node/bun policy: a bad release lands on `mise upgrade`, not
  on shell start.
- **Rejected: mise-only uv** — breaks the systemd unit and `agent-tools.sh`.
- **Rejected: `uv self update`** — the nix build is read-only; it refuses.
- **Rejected: bumping nixpkgs** — a whole channel move for one CLI.

## Risks

- `sudo` needs a password: `update-nixos.sh` falls back to `sudo -A` + zenity,
  so a password dialog appears on the desktop.
- The rebuild carries the whole `nix/` tree, not just this line. Verified safe:
  `/etc/nixos/configuration.nix` is byte-identical to the repo copy and
  `/run/current-system` was built from it today at 08:49, so this line is the
  only delta.
- Two uv versions coexist. Both write `~/.local/bin` links, `~/.local/share/uv`
  tools and python installs, so state is shared and does not fork; the only
  divergence is which version runs the command.
- mise's uv is a foreign glibc ELF and runs through nix-ld, like node. Low risk,
  proven path on this host.
