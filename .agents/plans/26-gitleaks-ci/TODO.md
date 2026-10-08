# TODO — epic 26

- [x] `setup/packages.list`: add `gitleaks` to `[dev]`, `check:gitleaks`, `p2`
- [x] `nix/configuration.nix`: add `gitleaks` to `environment.systemPackages` `[dev]` block
- [x] `.gitleaksignore`: baseline the 5 historical fingerprints from `git log`
- [x] `.github/workflows/gitleaks.yml`: `gitleaks-action@v3` + `checkout@v6`, push/PR/dispatch
- [x] local check: `gitleaks detect` exits 0 on the current checkout (exits 1 with the ignore file removed — the baseline is load-bearing, not decorative)
- [x] local check: `gitleaks` on PATH — `/run/current-system/sw/bin/gitleaks`, version 8.30.1, `detect` exits 0
- [x] verify: `nix-instantiate --parse nix/configuration.nix` OK; workflow YAML parses (`yq '.on'` → push, pull_request, workflow_dispatch)
