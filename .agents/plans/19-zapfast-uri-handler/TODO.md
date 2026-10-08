# TODO — zapfast URI handler

**All items below are historical — the epic is DROPPED as of 2026-10-08.**
`nix/zapfast-uri/` was deleted (zapfast too immature to carry a local patch
flake); the boxes stay ticked because the work *was* done and verified, it just
no longer lives in this repo. Upstream PR #426 is still open. See PLAN.md.

- [x] 1. `nix/zapfast-uri/uri-handler.patch` — add `src/target.rs` (parser +
      tests), wire `Cli.target`, `ControlCommand::OpenChat`, `Action::StartChat`
      dispatch, desktop entry `Exec=zapfast %U` + `MimeType=`
      (also fixes `packaging/install-user.sh`, which rewrote `Exec=` and
      dropped the field code; its test now asserts `%U` survives)
- [x] 2. `nix/zapfast-uri/flake.nix` — `flake:nixpkgs` → `zapfast.overrideAttrs
      { patches = [ ./uri-handler.patch ]; }`
- [x] 3. `nix eval` resolves: `zapfast-0.19.0`, src `s00avs2nf…` (same as
      nixpkgs, so the patch applies to the packaged tree)
- [x] 4. Build via ajq; `doCheck` phase green (parser + Cli tests)
      - attempt 1 (`j-7c496731dd53`): build compiles, 1045 tests pass, **2 of
        mine fail** — `https://wa.me/<n>/` (trailing slash emptied the path)
        and `phone=%2B<n>` (cutting at `%` dropped the number). Fixed in
        `digits_of`: strip `%2B`/`%2b` after the parameter cut, trim
        trailing `/` in `path_of`. Verified against 32 cases in a standalone
        harness (`rustc -O`, no deps) before rebuilding.
      - attempt 2 (`j-762b3c994a5a`): killed by an ajqd restart mid-build
        ("interrupted by the user"); resubmitted after `ajq daemon ensure`
      - attempt 3 (`j-81ed315ffc61`): **green** — `test result: ok. 1047
        passed; 0 failed; 9 ignored` (+8 / +2 in the other targets), all 11
        new tests listed as ok in `nix log`, store path
        `/nix/store/rklppvjh0gi41g5z47z9n0wa0qrkhi8y-zapfast-0.19.0`
      - rustfmt 1.98.0 clean; `patch -p1` dry-run + real apply against the
        nixpkgs src tree, `packaging/test-install-user.sh` passes on the
        applied tree
- [x] 5. `nix profile install` the patched package — **0.18.2 → 0.19.0**
      (`/nix/store/rklppvjh0gi41g5z47z9n0wa0qrkhi8y-zapfast-0.19.0`).
      The old `github:crmne/zapfast` entry was removed first: both claim
      priority 5, so an install alongside it is refused.
- [x] 6. Desktop symlink needed no change — it points at
      `~/.nix-profile/share/applications/zapfast.desktop`, which follows the
      profile to the new store path. Verified.
- [x] 7. `xdg-mime default zapfast.desktop x-scheme-handler/{whatsapp,wa}` →
      both query back as `zapfast.desktop`;
      `desktop-file-validate` clean on the entry
- [x] 8. Verified: `zapfast --help` shows `[TARGET]`; `zapfast not-a-chat`
      exits with "cannot read a phone number"; `gio open whatsapp://…`
      reaches the running copy ("asked it to open the chat"); the user
      confirmed **a real contact opens its existing chat with history**, so
      the `@lid` risk did not bite
- [x] 9. `gh issue create --repo crmne/zapfast` (D7) → issue **#407**
      ("Open a chat from the command line, a wa.me link, or a
      whatsapp:// URI"), filed with the verified console output and the
      scope note about `install-user.sh` rewriting `Exec=`
- [x] 11. **Template follow-up** (the user's question: what about
      `?text=…`?). The shipped patch dropped `text=` silently, which is most
      share links. Extended:
      - `target::Request { chat, text }`; `parse` reads `phone=`/`text=` from
        the query in either order and decodes both, UTF-8 included
      - `Request::verb()` / `from_verb()` round-trip over the one-line socket
        (`open <chat>\t<escaped>`), so a tab or newline in a template cannot
        break the framing
      - `Action::PrefillComposer(String)` puts it in the composer without
        sending; refuses to overwrite what is being typed or edited, and is
        not in `allowed_while_locked`
      - verified standalone (pure std, `rustc -O`) over 13 accepted forms, 9
        template cases, 13 refusals, 7 verb validations: 0 failures
      - rebuild 1 (`j-d622d33ba11d`): 1053 pass, **1 of mine fails** —
        `a_request_survives_the_wire` held `text: Some("   ")`, but a blank
        template is deliberately no template, so `from_verb` returns `None`.
        My test asserted identity where the rule says otherwise. Fixed at the
        source instead of the assertion: `verb()` now applies the same blank
        filter `parse` does, so a request cannot put a blank on the wire, and
        the case moved to its own test naming the rule.
      - rebuild 2 (`j-8df0ab70123d`): **green** — `1055 passed; 0 failed;
        9 ignored` (+9 / +2), all 16 `target::tests` and 4
        `target_cli_tests` ok. Store
        `/nix/store/0gg04dys6gyjrv5hk2jqy17m5v2lhhin-zapfast-0.19.0`.
      - reinstalled into the profile. The flake is `git+file://`, so it reads
        the **git tree**, not the working tree: the regenerated patch had to be
        `git add`ed, and `nix profile install` then still said "already
        added" and kept the old store path — it had to be `remove`d first.
      - live socket matrix against the new binary
        (`/proc/<pid>/exe` confirmed `0gg04dys…`, not the older `rklppvjh…`
        that was still holding the slot):
        `open <jid>` accept, `open <jid>\t<escaped>` accept, blank template
        accept-and-dropped, and `@lid` / too short / too long / wrong server /
        no argument / unknown verb all **refused**.
      - the user confirmed a template link **opens with the text in the
        composer**. Epic complete.
- [x] 10. Final check: `bash link-files.bash --audit` → **Audit clean (78
      links correct)**, wayland context. `nix/` is not scanned, so the flake
      and patch added nothing to `$HOME`.
- [x] 12. **Upstream PR** (the user's call: fork it and open a PR)
      - forked `crmne/zapfast` → `assawalhy/zapfast`, branch
        `feat/uri-handler` off `main` at `63ed17c`
      - the patch applied with **zero fuzz**, so no rebase was needed
      - read `CONTRIBUTING.md` + `AGENTS.md` first: one concern per PR, docs
        in the same PR, no em dashes in user-facing writing, screenshots only
        if the app looks different
      - documented in `docs/_guide/using-zapfast.md` as a new `## Links`
        section, plus the front-matter description
      - **all six CI checks pass locally** in `nix develop`:
        fmt, clippy, clippy --all-features, test (1097 passed / 0 failed /
        9 ignored, +9 +2), test --all-features (1097 / 0 / 9, +11 +2),
        rustdoc under `-D warnings`
      - **PR https://github.com/crmne/zapfast/pull/426** — MERGEABLE, 10
        files, +653/-11, closes #407
      - honest gaps stated in the PR body: macOS and Windows not run (CI
        will say); `update-translations.sh --check` not run (no GNU gettext
        with Rust support on this machine) though the change adds no `gettext`
        literal; the test profile was built with `CARGO_PROFILE_TEST_DEBUG=0`
        to fit the linker, which changes debug info only
      - `triage / assess` failed, but that is the maintainer's own bot erroring
        on its validation ("left for a maintainer"), not a code check
## Review rounds (2026-10-06/07)

CodeRabbit requested changes three times. **All findings were verified against
the code before acting; every one was valid.** Nothing was accepted on the
bot's word, and nothing was argued away.

- **Round 1 — 4 findings, `c1a79e5`**
  1. the guide's `xdg-open 'https://wa.me/…'` example does not reach zapfast
     (it goes to the browser, and the section says so below it)
  2. a template could land in the **wrong chat**: `open_chat` returns early for
     a locked chat *without changing `self.open_chat`*, so the `is_some()`
     guard passed for the previous chat. `PrefillComposer` now carries its chat
  3. a link was **dropped while the app lock was up** — and the PR body claimed
     it waited. It now defers in `app_lock.deferred_request` and replays on
     unlock, as a clicked notification does
  4. a template **destroyed the reader's saved draft**: leaving the chat did
     `drafts.insert(previous, draft)` and `store_draft` over it
- **Round 2 — 6 findings, `8ebcca9`**
  1. a query lent its digits to the number: `wa.me/2012?text=999999` read as
     `2012999999`. **The worst of the lot**; the path was taken from the whole
     argument instead of the part before the query
  2. `phone=` accepted from any host (`https://example.com/?phone=…` opened a
     chat). The number is now read only where the shape keeps it
  3. letters were deleted rather than refused (`call 20123456789` named a chat)
  4. **only 1 of 5 draft-saving paths knew about a template** — round 1's fix
     was incomplete: `park_composer`, `CloseChat`, `hide_locked_chat`,
     `flush_open_draft` all still stored it. One predicate now covers all five
  5. a prefill discarded an armed reply
  6. `--start-hidden` with a chat left it in the tray
- **Round 3 — 1 finding, `71a8ce9`**
  1. a fragment hid the number (`wa.me/20123456789#section`) and reached the
     composer (`text=Hello#section`). Split off before the query

### Lessons worth keeping
- The bot found **two bugs I had introduced and would not have caught** (the
  query lending digits, the fragment). Both were in the parser I wrote and
  tested 20 ways. My tests covered the shapes I thought of; it probed the ones
  I did not.
- **My first fix was too narrow** (round 2, finding 4). I fixed the one path I
  was looking at instead of asking which other paths share the rule. Worth
  grepping for siblings before declaring a bug fixed.
- Every round, `cargo test` was green while a real bug was live. Tests confirm
  what you thought of, nothing else.
- `triage / assess` shows `fail` on the PR, but it is the maintainer's bot
  cancelling its own duplicate runs ("Canceling since a higher priority
  waiting request ... exists"), never a code check.

## Cross-repo note
PR **#423** ("Reconcile chat history after LID mapping", `nathanbzrr`) credits
`@assawalhy` for the identity/history issue reported in **#407** — the LID
caveat written as a scope note in that issue turned into someone else's fix.
It touches only `src/archive.rs`, no overlap with #426. The PR body now
cross-references #423 instead of listing the empty-chat behaviour as a flaw.
