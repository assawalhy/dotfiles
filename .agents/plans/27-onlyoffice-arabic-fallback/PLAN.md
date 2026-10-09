# 27 — Arabic in ONLYOFFICE for Word templates naming Arial

## Goal
A customer `.docx` whose font is a Latin-only face (Arial, Calibri, Times New
Roman, …) shows Arabic instead of `.notdef` boxes in ONLYOFFICE Desktop,
without changing the template or disturbing the generated PDF.

## Root cause (verified)
- The template sets `<w:rFonts w:ascii="Arial" w:cs="Arial" …/>` on every run.
- Arial is absent; fontconfig metric-aliases it to Liberation Sans (no Arabic).
- LibreOffice/Gotenberg fall back per glyph to DejaVu, so generated PDFs render
  fine (`bond-infra-gotenberg-1` → correct Arabic, `pdftotext` reads `عرض سعر`).
- ONLYOFFICE does **not** fall back per glyph. `FC_DEBUG=7` on the running app
  shows it issues `FcConfigSubstitute` with exactly:
  `family: "Arial"(s), slant: 0, lang: "en"(w), prgname: "DesktopEditors"`.
  No `lang: ar`, no `charset`. It resolves Arial → Liberation Sans and draws
  `.notdef` for every Arabic glyph.

## What does not work (probed 2026-10-09)
- **`lang=ar` fontconfig rules** — ONLYOFFICE never puts `ar` on the pattern,
  so the rule can never fire. (Rule verified with `fc-match` but ineffective in
  the app.) Reverted.
- **Changing the document's `w:cs`** — ONLYOFFICE honours `w:cs` (it then
  queries `Noto Sans Arabic` 10×, `Arial` 0×) but uses **one font per run**.
  Since the runs hold both the Arabic label and its Latin value, an Arabic-only
  face (Noto Sans/Naskh Arabic carry no Latin letters) would box the Latin.
- **Bundling a face into the onlyoffice FHS rootfs** — it still resolves
  Arial → Liberation; only helps if it did glyph fallback, which it does not.

## Approach (proposed, needs approval)
App-scoped fontconfig substitution: for `prgname="DesktopEditors"` and a
Latin-only family, prepend a **both-script** face — `DejaVu Sans` (Latin +
Arabic, and the exact face Gotenberg already falls back to for Arabic).
- `Arial`, `Helvetica`, `Segoe UI`, `Tahoma`, `Calibri` → `DejaVu Sans`
- `Times New Roman` → `DejaVu Serif`
- `Courier New` → `DejaVu Sans Mono`
Scoped by `prgname` so the rest of the system keeps Arial → Liberation.

## Decisions
- **`prgname` scope, not global.** A global `Arial → DejaVu Sans` would shift
  every app's Arial metrics. Verified: `Arial` stays Liberation Sans;
  `Arial:prgname=DesktopEditors` → DejaVu Sans.
- **Both-script face, not an Arabic-only face.** Noto Sans/Naskh Arabic have no
  Latin (verified via charset), so they box the Latin in the same run.
- **`DejaVu Sans`, not Amiri.** Amiri also has both scripts but is a naskh serif;
  DejaVu Sans keeps the sans look and matches the PDF's Arabic fallback.

## Trade-off (call this out)
ONLYOFFICE will render Arial text — including the document's Latin — in DejaVu
Sans, which is slightly wider than Arial. The generated PDF is untouched
(Liberation for Latin, DejaVu for Arabic). So the editor preview and the PDF
differ for Latin only; Arabic is correct in both.

## Alternative (if the trade-off is unacceptable)
Make the template use a single both-script face for all four `w:rFonts`
attributes (e.g. `DejaVu Sans`), or merge Liberation Latin + Noto Arabic into a
font named `Arial`. Both change the document's Latin rendering too; the merged
font is the only way to keep Arial metrics *and* Arabic in one face.

## Milestones
1. Add the `prgname`-scoped rules to `configuration.nix`; parse check.
2. Probe with `FONTCONFIG_FILE` (no rebuild): ONLYOFFICE shows Arabic.
3. Rebuild + switch; visual check.
4. Commit.

## Risks
- Rebuild is the long pole; run it queued/background.
- If `prgname` is not set on some query path, the rule silently won't fire —
  the probe catches that before the rebuild.
