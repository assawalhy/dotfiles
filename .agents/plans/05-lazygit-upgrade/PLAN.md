# 05 — lazygit upgrade

## Goal
Get lazygit ≥ 0.64 on the NixOS box so the committed
`common/.config/lazygit/config.yml` (`git.diffRenderers`) actually applies.
The `nixos-26.05` channel pins 0.61.1 (and the release branch never moved);
pull just lazygit from a pinned nixpkgs-unstable rev (0.65.1).

## Approach
Add a pinned `unstable` nixpkgs import to configuration.nix's `let` block and
reference `unstable.lazygit` in `environment.systemPackages` instead of `lazygit`.
Everything else stays on the nixos-26.05 channel.

## Decisions
- **Only lazygit from unstable**, system stays 26.05. Rejected: channel bump
  (verified still 0.61.1), tracking unstable wholesale (broad risk), flakes
  conversion (out of scope), `overrideAttrs` source bump (recompiles, vendorHash
  upkeep), upstream release tarball (bypasses nixpkgs, x86_64-only).
- **`builtins.fetchTarball` pinned by rev + sha256.** Rejected: hash-less fetch
  (not reproducible), `<nixpkgs-unstable>` channel (mutable, not committed).
- **`config.yml` unchanged** — it is correct for ≥ 0.64; the version was the bug.
  Rejected: revert to `git.paging` (loses diffRenderer arrays).

## Milestones
1. Pin + swap lazygit in configuration.nix.
2. Validate eval / dry-run (fetch-only, no compile).
3. Rebuild; verify version + delta renders.

## Risks
- Second nixpkgs eval adds ~1–2 s; one-time ~35 MB tarball fetch.
- Pin is frozen; bump consciously.
- `configuration.nix` carries live uncommitted work (plans 03/04) — the switch
  applies those too, and the commit must stay scoped.
