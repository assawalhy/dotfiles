# Epic 26 — gitleaks locally + secret-scan CI

## Goal
Install `gitleaks` through the normal dotfiles package path, and add a GitHub
Actions workflow that fails a push to **any** branch when a secret is committed.

## Approach
Three independent pieces, no new runtime dependencies beyond the nixpkgs package:

```
nix/configuration.nix   + gitleaks   -> installed on this NixOS box
setup/packages.list    + gitleaks   -> installed by setup-os elsewhere (mirrors systemPackages)
.github/workflows/
  gitleaks.yml                       -> CI gate on every branch push
.gitleaksignore                      -> baseline of 5 pre-existing (2020-2021) findings
```

CI uses the official `gitleaks/gitleaks-action@v3` (Node 24) with
`actions/checkout@v6` + `fetch-depth: 0`. v3/v6 are required: Node 20 actions
are removed from GitHub-hosted runners on 2026-09-16, so `v2`/`checkout@v4`
would start failing. `GITLEAKS_LICENSE` is omitted — this is a personal
account, where the license is not required.

## Decisions
- **`gitleaks-action@v3` + `checkout@v6`, not the raw CLI in a container** —
  the action already pins a gitleaks version, uploads a SARIF artifact, and
  comments on PRs. Rejected: `nix run nixpkgs#gitleaks` in a workflow (rebuilds
  nixpkgs in CI, slow, no PR comments); rejected: a `pre-commit` hook (not a CI
  gate, and this repo has no hook infra).
- **Triggers `push` (all branches) + `pull_request` + `workflow_dispatch`** —
  `push` is the ask; `pull_request` is added because it is the only trigger
  that can comment inline on the offending line, which is where the value is.
  No `schedule` — a daily cron re-scanning 2.6 MB of history adds nothing.
- **`.gitleaksignore` with the 5 historical fingerprints** — the current tree
  is clean, but the full history is not. Without a baseline, the first push to
  a *newly created* branch (where `before` is all-zeros and the action scans
  the whole history) would fail on findings that predate this workflow.
  Rejected: `allowlist` paths in a `gitleaks.toml` (blanket-bans `*/.gitconfig`
  forever, which is exactly where a real leak would land); rejected: rewriting
  history to purge them (destroys 290 commits and every existing PR ref for two
  stale, already-dead credentials).
- **Scan `detect` (git history), never `dir .`** — `dir .` reports 71 false
  positives from the untracked, globally-ignored `.zvec-grep/` rocksdb index.
  The action scans git history, so this is a local-usage note, not config.
- **Package via nixpkgs + `packages.list` (p2)**, matching every other tool in
  this repo — `nixpkgs#gitleaks` is 8.30.1 on the 26.05 channel.

## Risks
- **A leaked npm token sits in history — resolved.** Commit `2981af6`
  (2020-09-01) contains `_authToken=5942bec4-…` in `.npmrc`, plus GPG
  signing-key fingerprints in three old `.gitconfig` revisions. The token was
  **revoked at npmjs.com, confirmed 2026-10-08**, so baselining it in
  `.gitleaksignore` suppresses a dead credential, not a live one. No history
  rewrite needed.
- The NixOS rebuild to install the binary needed `sudo`; done 2026-10-07
  (`/run/current-system/sw/bin/gitleaks`, 8.30.1, `detect` exits 0).
