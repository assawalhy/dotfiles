# Plan: Copyous auto-paste picks the wrong clipboard buffer in terminals

## Goal
Selecting an item in Copyous ("auto-paste") must insert **that item** into the
focused app — images included — even in WezTerm, and regardless of the
`sync-primary` toggle. Fix a corrected extension for us on NixOS, file an
upstream issue, and open a PR.

## Findings (verified)
- Copyous 2.0.1 (EGO v9). `ClipboardManager.pasteContent`
  (`src/lib/misc/clipboard.ts`) copies the item to CLIPBOARD, then after 250 ms
  replays a paste chord picked by
  `Main.inputMethod.content_purpose === TERMINAL`: `Ctrl+Shift+Insert` for
  terminals, `Shift+Insert` otherwise.
- WezTerm never sets the Wayland text-input content purpose
  (`wezterm/window/src/os/wayland/inputhandler.rs` only handles
  preedit/commit/done), so purpose is always NORMAL → Copyous always sends
  `Shift+Insert`.
- WezTerm binds `SHIFT+Insert` to `PasteFrom="PrimarySelection"`
  (wezterm.org default-keys), **not** CLIPBOARD. Images are never put on PRIMARY,
  and text only when `sync-primary` is on. So terminal auto-paste reads a stale
  PRIMARY: image → last text; `sync-primary` off → last manually copied text.
- GUI apps treat `Shift+Insert` as a clipboard paste → unaffected. Manual
  `Ctrl+Shift+V` reads CLIPBOARD → unaffected. This is exactly the reported
  split (terminal broken, GUI fine, manual fine).
- current dconf: `sync-primary=true` → text happens to work, images do not.
- Related upstream issues: #124 (auto-paste no-op; proposes Ctrl+V / Ctrl+Shift+V
  + purpose save), #134 (`Ctrl+Shift+Insert` unbound in Ghostty), #159 (primary
  selection), #69/#140. No open PR addresses the stale-PRIMARY paste.
- nixpkgs ships the prebuilt EGO zip; `extensionOverrides.nix` already patches
  its compiled JS in `preInstall`, so the same derivation can be overridden.
- Terminal `.desktop` files here carry `Categories=…TerminalEmulator…`
  (WezTerm, Ghostty, Console, XTerm) — a generic terminal signal via
  `Shell.WindowTracker` + `Gio.DesktopAppInfo.get_string('Categories')`.

## Decisions
- D1 Chord: non-terminal → `Ctrl+V`; terminal text/file → `Ctrl+Shift+V`;
  **image (any target) → `Ctrl+V`** (terminal paste cannot carry images; a
  clipboard-reading TUI like opencode needs the raw key). Rejected: keep
  `Shift+Insert` (primary bug); `Ctrl+Shift+Insert` (unbound in WezTerm/Ghostty);
  `Ctrl+Shift+V` for images too — the terminal binds it to its own text paste
  (`PasteFrom="Clipboard"`), so the key never reaches opencode, and an image-only
  clipboard has no text to forward. opencode's `input_paste` reading the OS
  clipboard only runs on `Ctrl+V`, which WezTerm leaves unbound and forwards.
- D2 Terminal detection: focused window's app `Categories` contains
  `TerminalEmulator` OR IME purpose `TERMINAL`, captured in
  `ClipboardDialog.open()` before `Main.pushModal`. Rejected: hardcoded
  wm_class list; WezTerm-only special case; content-purpose alone (WezTerm never
  sets it).
- D3 Local delivery: a real unified diff at
  `nix/copyous-terminal-paste/terminal-paste.patch` (the same shape nixpkgs uses
  in `extensionOverridesPatches/*.patch`), applied by a
  `patches = (old.patches or []) ++ [ ./copyous-terminal-paste/... ]` overlay in
  `nix/configuration.nix` — relative, no hardcoded repo path. The deploy is
  `nix/update-nixos.sh` (epic 24), which mirrors `nix/` onto `/etc/nixos`, so it
  survives a new system or a moved repo. Plus an immediate user-dir copy of the
  patched JS so the fix works without waiting for a rebuild. Rejected: inline
  Python `postPatch` (ugly, escaping-prone — the first cut); flake under `nix/`
  (adds a lock + a second nixpkgs for no gain over a plain patch);
  build-from-source override (pnpm + extensions-tool in sandbox).
- D4 Upstream: new issue for the stale-PRIMARY/WezTerm symptom + a PR that
  references #124.

## Milestones
1. Branch off `main`: fix `clipboard.ts` (chord + terminal detection) and
   `clipboardDialog.ts` (capture target before the modal).
2. Typecheck + lint the branch (`pnpm exec tsc --noEmit`, eslint, prettier).
3. Fork, push the branch, open the PR; file the issue with root cause + repro.
4. Local: `nix/copyous-terminal-paste/terminal-paste.patch` + relative overlay in
   `configuration.nix`, and an immediate user-dir copy of the patched JS.
5. Validate with `nixos-rebuild build`; deploy (`configuration.nix` + `nix/` to
   `/etc/nixos`, `nixos-rebuild switch`) and re-login — handed to the user (no
   `sudo` in this container).
6. Verify: image auto-paste in opencode → `[Image 1]`; `sync-primary=false` text
   → correct item; shell text still pastes; GUI unaffected; no journal errors.
7. Commit dotfiles.

## Risks
- A terminal app that is untracked or lacks the `TerminalEmulator` category falls
  back to `Ctrl+V` (text into its shell will not auto-paste). WezTerm/Ghostty/
  Console verified categorized.
- Wayland requires a re-login to load the patched system extension.
- This shell runs in a container with the `no new privileges` flag, so `sudo`
  (and therefore `nixos-rebuild switch`) cannot run here; the user must run the
  switch on the host. The build itself was validated with
  `nixos-rebuild build` (exit 0).
- Compiled-JS patch is pinned to EGO v9; a Copyous bump fails the build loudly
  (same pattern as the existing ranger overlay).
- The PR may not be merged upstream; the local fix stands on its own.
