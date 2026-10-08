# PLAN — zapfast URI handler (whatsapp:// + wa.me links)

> **DROPPED 2026-10-08 — kept as a record, not as live work.**
> `nix/zapfast-uri/` was deleted: zapfast is not mature enough to carry a local
> patch flake, and the feature now lives upstream anyway. The uninstall side was
> already done in epic 21; nothing here is installed and no box has zapfast on
> `PATH`. The work survives in PR
> <https://github.com/crmne/zapfast/pull/426> (still **open**, not merged) on
> `assawalhy/zapfast` branch `feat/uri-handler` — delete this epic's own copy of
> the patch from git history only if you decide to close that PR. Everything
> below is a snapshot of how it was built; the two `nix/zapfast-uri/` file paths
> it refers to no longer exist.

## Goal
`xdg-open whatsapp://send?phone=…` and `zapfast wa.me/<number>` open the chat
in ZapFast instead of failing. Scheme registered, app accepts a target.

## Findings (verified 2026-10-05)
- zapfast has **no URI support at all**, upstream or local:
  - `Cli` (`src/main.rs`) = `verbose`, `start_hidden`, demo flags,
    `Control::ReloadThemes`. `zapfast 2012…` → `error: unrecognized subcommand`.
  - desktop entry: `Exec=zapfast`, **no `%U`**, **no `MimeType=`**.
  - `gio open whatsapp://send?phone=…` → `The specified location is not supported`.
  - single-instance verbs (`src/single_instance.rs::parse`) = `show`,
    `reload-themes`, `ping`. Nothing can open a chat remotely.
  - Same in 0.19.0 and `main` (63ed17c). No open upstream issue/PR for
    `wa.me`/deeplink.
- The capability is one hop away: `Action::StartChat { id, name }`
  (`src/app.rs:4107`) creates the chat, sends `Command::EnsureChat`, opens it.
  `handle_control_commands` (`src/app.rs:1460`) is where a verb becomes an
  action; the queue is already plumbed.
- `https://wa.me/…` already opens Brave — correct, leave it.
- Build is mostly cached: `nixpkgs#zapfast` = 0.19.0, `patches = []`
  overridable, `src` and the cargo vendor deriv are in cache.nixos.org.
  Only zapfast's own crate compiles locally.

## Approach
```
whatsapp://send?phone=2012… ─┐
zapfast wa.me/2012…  ─┼──→ target::parse() → "<digits>@s.whatsapp.net"
zapfast +2012…               ─┘         │
                                       ├─ already running → verb "open <id>"
                                       │    → ControlCommand::OpenChat
                                       │    → Action::StartChat
                                       └─ first launch → app.actions.push(…)
```

## Scope
```
 nix/zapfast-uri/{flake.nix,uri-handler.patch}   new
 ~/.config/mimeapps.list                         +1 line
 ~/.local/share/applications/zapfast.desktop     re-pointed symlink
 ~/.nix-profile                                  0.18.2 → patched 0.19.0
 gh issue create --repo crmne/zapfast            upstream request (D7)
```
`nix/` at repo root is not scanned by `link-files` (only `common/` +
`linux/`/`macos/`), so nothing lands in `$HOME`.

## Decisions
- **D1** — Patch `flake:nixpkgs#zapfast` (0.19.0), not the pinned
  `github:crmne/zapfast` flake (locked 0.18.2). One flake to track,
  `patches` overridable, deps cached.
- **D2** — Keep `doCheck = true`. The patch adds parser + `Cli` tests; the nix
  check phase runs them. One-off build cost is worth shipping tested arg
  parsing.
- **D3** — Strict patch, no `fuzz`. A silent mis-apply that compiles is worse
  than a build failure.
- **D4** — New module `src/target.rs`, exported from `lib.rs`. Upstream
  separates parsing from the app; a `main.rs` helper is untestable there.
- **D5** — Register the scheme in `~/.config/mimeapps.list`
  (`[Default Applications]`), next to the existing
  `x-scheme-handler/opencode` line. Kept out of the repo: `xdg-mime` rewrites
  that file, so a committed symlink would fight it.
- **D6** — Re-point `~/.local/share/applications/zapfast.desktop` at the new
  store path. It currently targets the 0.18.2 path and will dangle.
- **D7** — File the upstream issue so this patch is temporary and can be
  deleted when the feature lands.
- *Rejected:* clipboard shim (`wl-copy` the number, launch zapfast, paste
  manually). No rebuild, but the chat is still picked by hand.

## Follow-up: the `text=` template (asked after shipping)

The first patch opened the chat and **silently dropped `text=`**, which is most
share links. Extended rather than left as a known gap:

- `target::Request { chat, text }`; `parse` reads `phone=` and `text=` from the
  query in either order and decodes both. `+` stays a plus, because a number
  writes it `%2B` — this query is escaped, not form-encoded. An escape that is
  not two hex digits is kept as written rather than allowed to swallow the
  rest of the template.
- `Request::verb()` / `from_verb()` round-trip the template over the one-line
  socket as `open <chat>\t<escaped>`: a space would end the verb, a newline
  would end the line. `from_verb` holds the chat to the same rule `parse`
  does, so a request from another launch cannot name an id this copy would not
  have opened.
- `Action::PrefillComposer(String)` fills the composer without sending. It
  refuses to overwrite what is being typed or edited, and it is not in
  `allowed_while_locked`, so a link cannot type into a locked app.
- A blank template is no template, in `parse`, in `verb()`, and on the way back
  out of `from_verb` — the same rule at both ends of the wire.

## Verification (2026-10-05)
- `doCheck` green: **1055 passed, 0 failed, 9 ignored** (+9 / +2 in the other
  targets), 20 new tests.
- Installed: `/nix/store/0gg04dys6gyjrv5hk2jqy17m5v2lhhin-zapfast-0.19.0`,
  profile 0.18.2 → 0.19.0.
- Live socket matrix against the running binary: plain chat and
  chat+template accepted; blank template accepted and dropped; `@lid`,
  too-short, too-long, wrong-server, no-argument and unknown verbs refused.
- The user confirmed both by hand: a **real contact opens its existing chat
  with history** (so the `@lid` risk did not bite), and a template link
  **opens with the text in the composer**.
- `bash link-files.bash --audit` → Audit clean (78 links correct).

## Milestones
1. Patch + flake written, `nix eval` resolves.
2. Build via ajq, check phase green.
3. Install into profile, register the scheme.
4. Verify end to end.
5. File upstream issue (D7).

## Risks
- First build 20-40 min (ajq-queued, one-off; later rebuilds recompile only
  zapfast's crate).
- A chat opened by phone number is `@s.whatsapp.net` while existing history
  may be filed under a `@lid` id. **Not observed** — the user confirmed a real
  contact opens its existing chat — but it is the property upstream's own
  phone-number menu (PR #303) has, so it can still happen for a contact whose
  mapping is not yet known.
- `https://wa.me/…` clicked in a browser still opens WhatsApp Web: GIO
  dispatches by scheme, and claiming `https` would hijack every web link.
- Patch breaks when upstream touches `main.rs` / `app.rs` / `model.rs` /
  `single_instance.rs` (loud, per D3).