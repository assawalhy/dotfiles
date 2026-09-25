# 06 — Arabic monospace font (Kawkab) system-wide

## Goal
Arabic text rendered in monospace contexts (terminal, code editors) uses the
repo's Arabic monospace face, Kawkab Mono — **system-wide**, not per-app.

## Root cause
- The generic `monospace` → Kawkab binding in `configuration.nix` only fires
  when a program requests the **generic** `monospace` family.
- Apps that request a concrete monospace family (Ghostty asks for
  "JetBrainsMono Nerd Font") bypass it, so Arabic fell back to proportional
  Noto Sans Arabic.
- The first attempt (Ghostty `font-codepoint-map`) fixed only Ghostty.

## Approach
Add a fontconfig `localConf` rule that fires for **any monospace request whose
charset includes the Arabic block**, using two properties:
- `spacing=mono` — how monospace apps mark the request (Ghostty's
  `toFcPattern` always sets it; terminals/editors do too).
- `charset contains U+0600-U+06FF` — per-glyph fallback puts the missing
  codepoint in the pattern's charset.

## Decisions
- **Fontconfig, not any app config.** System-global by construction; the
  Ghostty-only file was removed.
- **Scope with `spacing=mono` + `charset`.** Verified against `fc-match`:
  concrete-family Arabic fallback → Kawkab; the app's primary/Latin font,
  explicit Arabic faces (Amiri, Noto Sans Arabic), and generic serif/sans are
  all unchanged. Rejected: unconditional `lang=ar` prepend (hijacks Arabic
  sans/serif UI text), `append` variants (can't outrank fontconfig's Arabic
  auto-fallback), no-fontconfig app hacks (not global).
- **Range U+0600–U+06FF only.** Kawkab's coverage; Supplement (0750) and
  Extended-A (08A0) fall through to fontconfig (readable, not tofu).

## Verification
- `fc-match` matrix (see epic notes): all desired outcomes hold.
- After rebuild: `fc-match "JetBrainsMono Nerd Font:spacing=mono:charset=0628"`
  → Kawkab; `fc-match "JetBrainsMono Nerd Font:spacing=mono"` → JetBrainsMono.
- Visual: Arabic in a new terminal is fixed-width; GUI Arabic UI is unchanged.
