# PLAN — kulala.nvim backend download fails

## Goal
`<leader>Rs` in a `.http` file works again. Today it dies with
`Backend installation failed or binary is not accessible`.

## Findings (verified 2026-10-06)

The plugin is fine. The **backend binary source moved behind a license server**.

**Installed state**
- `common/.config/nvim/lua/plugins/editor.lua:142` → `mistweaverco/kulala.nvim`,
  locked at `232a993` (branch `main`).
- That commit pins `BACKEND_VERSION = "0.37.0"`
  (`lua/kulala/globals/versions/backend.lua`).
- No binary on disk: `~/.local/share/kulala.nvim/bin/` absent,
  `~/.local/share/kulala-core` absent.

**Why the download fails — the old URL is dead**
- Installed version builds
  `https://github.com/mistweaverco/kulala-core/releases/download/v0.37.0/kulala-core-linux-x86_64`.
- That returns **404**. So do the `dont-be-evil-company` equivalents, and
  `releases/latest` on both. The `kulala-core` repo is **not publicly readable** —
  `api.github.com/repos/{mistweaverco,dont-be-evil-company}/kulala-core` → 404
  unauthenticated *and* with a valid `repo`-scoped `gh` token. The `mistweaverco`
  org itself 301-redirects to `dont-be-evil-company`, so the plugin spec still
  resolves; only the release assets are gone.

**What upstream did instead — commit `7e740be` "feat(license-server)"**
(2026-09-29, in `main`, *not* in the locked `232a993`)
- `download_url` → `https://core.kulala.app/releases/%s/%s`
- `BACKEND_VERSION` → `1.3.1`
- `backend.lua` now requires a token: `Authorization: Bearer <token>` from
  `KULALA_CORE_LICENSE_TOKEN` or a saved token file; prompts with
  `vim.fn.inputsecret` otherwise.
- Verified: `https://core.kulala.app/releases/1.3.1/kulala-core-linux-x86_64`
  → **401** (also 401 with a dummy bearer).
- `https://core.kulala.app/pricing` redirects to a login wall
  ("Paste a long-lived API token"), so cost is not publicly stated. The vendor
  site says tools are "always for free"; `kulala.app/usage` calls kulala-core
  "proprietary". **Treat the token as a real unknown-cost gate until the user
  confirms they have one.**
- `@dont-be-evil-company/kulala-core` on npm is only a **downloader stub**
  (4.7 KB tarball, no binary) and still points at the dead GitHub URL — no
  token-free install path there.

So: `:Lazy update` alone gets the *new* download code, which then hard-fails
without a token. It does not fix this.

## Approach — branch on whether a token exists

### A. Token available (preferred, keeps everything)
1. Export `KULALA_CORE_LICENSE_TOKEN` in the shell env (not committed).
2. Bump the plugin spec `mistweaverco/kulala.nvim` → `dont-be-evil-company/kulala.nvim`
   and `:Lazy update` so the license-server download code lands.
3. Pin `kulala_core.download_url` explicitly to
   `https://core.kulala.app/releases/%s/%s` — the default, but stating it means
   a future upstream default change can't silently break the install again.

### B. No token (fallback: drop the plugin)
Remove the kulala spec from `editor.lua` and the `<leader>R*` maps. **No
drop-in replacement**: `rest.nvim` is unmaintained-ish (last push 2025-12-27)
and this repo's `lazy.lua:29` has `rocks = { enabled = false }`, which
`rest.nvim` needs. Cheapest working alternative is plain `curl` in a terminal.
Only do this if the user rejects the license gate.

## Rejected alternatives
- **Hand-place a 0.37.0 binary** — asset is 404 from every host; nothing to fetch.
- **Point `kulala_core.path` at a `bun run` source build** — `kulala-core` repo
  is not publicly readable, so there is no source to build.
- **npm-install `@dont-be-evil-company/kulala-core`** — stub only, dead URL.
- **Pin the plugin back** — the 0.37.0 asset is gone; older = still broken.
- **Add a `build =` step to the lazy spec** — doesn't help; the failure is a
  404/401 at the source, not a missing local build step.

## Risk
- Lockfile churn: `:Lazy update` moves kulala to a commit that also needs
  Neovim 0.12+ (have 0.12.4 ✓), `curl` ✓, `git` ✓, `tree-sitter` ✓.
- On NixOS the downloaded binary lands in `stdpath('data')` (a real writable
  `~/.local/share`), so no store-path issue — but it is unmanaged by Nix and
  will need re-downloading if `KULALA_CORE_LICENSE_TOKEN` changes.
