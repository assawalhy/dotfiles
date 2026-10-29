# Plan: Copyous clipboard history (Gda typelib)

**Status: implemented 2026-10-22, awaiting the switch and the re-login.**
Drafted 2026-10-20 from verified facts. Progress is in [TODO.md](TODO.md).

## Symptoms

1. Copyous logs `Failed to load Gda` and disables clipboard history. It falls back
   to an in-memory database, so every entry is lost on logout.
2. Terminal auto-paste inserts the primary selection instead of the clipboard
   (reported 2026-10-22). Same cause: the EGO updater installed copyous 2.1.1 into
   the user extension directory, which shadows the patched system copy, so epic
   23's fix is not loaded.

## Root cause: two layers, both verified

1. **A user copy shadows the managed extension.** GNOME Shell prefers
   `~/.local/share/gnome-shell/extensions/<uuid>` over the system directory.
   Copyous v11 (2.1.1, installed from extensions.gnome.org on Oct 16 and updated
   Oct 20 at 01:30) sits there and wins over nixpkgs' v9 (2.0.1). The v11 copy
   has no `GIRepository` prepend, so `import 'gi://Gda'` cannot find the typelib.
   It also lacks the terminal auto-paste patch from epic 23.
2. **The managed v9 copy cannot load Gda either.** The generated
   `Gda-6.0.typelib` lists `libxml2-2.0` as a prerequisite, and libxml2 in
   nixpkgs ships no typelib (checked `out` and `dev`, channel 26.05.10402 and
   nixpkgs-unstable). GJS aborts with `Typelib file for namespace 'libxml2',
   version '2.0' not found`. nixpkgs' `extensionOverrides.nix` for copyous only
   prepends libgda's own directory, so its Gda patch has never worked in this
   channel.

Evidence:

| check | result |
|---|---|
| user copy metadata | `version 11`, `version-name 2.1.1` |
| system copy metadata | `version 9`, `version-name 2.0.1` |
| `prepend_search_path` in the v11 copy | none |
| `prepend_search_path` in the v9 copy | libgda and gsound paths, both alive |
| `strings Gda-6.0.typelib` dependencies | `libxml2-2.0\|Gio-2.0\|GObject-2.0\|GLib-2.0` |
| libxml2 `out` and `dev` | no `.typelib` and no `.gir` |
| patched libgda build (experiment) | typelib deps `Gio-2.0\|GObject-2.0\|GLib-2.0` |
| GJS against the patched typelib | imports `Gda 6.0`, opens `clipboard.db`, counts 32 rows |

The experiment used the exact patch in D2, built as
`/nix/store/z1ssj97jxzlcn2pmsh0piyn98syg5vvl-libgda-6.0.0`.

## State that must survive

`~/.local/share/copyous@boerdereinar.dev/clipboard.db` holds 32 entries from
Oct 19 22:51, written by Gda with database version 2. Both v9 and v11 use
version 2, so the managed v9 can open it unchanged once Gda loads. The
`database-backend` dconf key is already `'sqlite'`, set by the extension when it
saw the `.db` file.

## Findings (verified 2026-10-22, the regression report)

1. **The user copy comes back on its own.** The EGO updater installed it and
   staged the next one:
   `~/.local/share/gnome-shell/extensions/copyous@boerdereinar.dev` is v11 /
   2.1.1, and `~/.local/share/gnome-shell/extension-updates/copyous@boerdereinar.dev`
   holds v12 / 2.1.2, both dated Oct 20 01:30. D1 alone therefore does not hold:
   the updater re-installs within a day.
2. **Upstream will not fix it soon.** copyous is at 2.1.2 (2026-10-18), issue
   [#168](https://github.com/boerdereinar/copyous/issues/168) and PR
   [#169](https://github.com/boerdereinar/copyous/pull/169) are both still open,
   and 2.1.2's `lib/misc/clipboard.js` still presses Insert when
   `keyboard.purpose === TERMINAL`. The terminal-paste fix is ours.
3. **No managed newer copy exists.** The pinned nixpkgs-unstable revision
   (`4975466d`) also carries `gnomeExtensions.copyous` version 9, so there is
   nothing newer to switch the overlay to today.
4. **nixpkgs has the prevention.** `gnomeExtensions.disable-extension-updates`
   (uuid `disable-extension-updates@swsnr.de`, version 10, `shell-version` 49 and
   50; this machine runs gnome-shell 50.4) patches GNOME Shell to skip updates of
   user extensions.
5. **copyous is the only user extension** in
   `~/.local/share/gnome-shell/extensions/`, so disabling user-extension updates
   has no other effect here.
6. **The loaded copy is the user one.** The journal stack traces name
   `file:///home/assawalhy/.local/share/gnome-shell/extensions/copyous@boerdereinar.dev/lib/...`,
   `isTerminalWindow` appears twice in the store copy's `lib/misc/clipboard.js`
   and zero times in the user copy's, and the same journal lines carry
   `Failed to load Gda` / `Using in-memory database`.

## Decisions

- **D1: delete the user copy** at
  `~/.local/share/gnome-shell/extensions/copyous@boerdereinar.dev` and the
  staging copy at
  `~/.local/share/gnome-shell/extension-updates/copyous@boerdereinar.dev`.
  That restores the managed v9, which has both the terminal-paste patch and the
  Gda wiring. The user copy has neither.
  - Rejected: patching the user copy. GNOME Shell or the EGO updater can replace
    it at any time, and it still lacks the terminal patch.
  - Rejected: packaging v11 as an overlay. Its `clipboard.js` still uses
    `keyboard.purpose === TERMINAL`, so `terminal-paste.patch` would need a
    re-port, and nixpkgs' version guard is built for v9. Follow-up when nixpkgs
    bumps.
- **D2: fix libgda at the source** with an overlay that removes `'libxml2-2.0'`
  from the `generate_gir` includes in `libgda/meson.build:387`. Copyous only
  needs the SQLite provider; none of the GIR-exposed functions that take
  `xmlNodePtr` are used, and the compiled typelib contains no XML symbols. The
  patch is guarded so a libgda bump fails loudly instead of silently dropping
  the fix.
  - Rejected: switch Copyous to its JSON backend (`database-backend=json`).
    Supported fallback and no rebuild, but it abandons SQLite, hides the existing
    32 entries, and leaves nixpkgs' Gda integration broken for every GJS
    consumer.
  - Rejected: build libxml2 with introspection. libxml2 is in most of the
    closure, so enabling GIR shifts a very large part of the store for a typelib
    that nothing else needs.
  - Rejected: byte-patch `Gda-6.0.typelib`. Not reproducible, dies on GC or the
    next rebuild.
  - Rejected: migrate the database to JSON with a script. Extra work and a
    one-way move, with no benefit once Gda loads.
- **D3: point Copyous at the patched libgda.** ~~`prev.gnomeExtensions.copyous`
  bakes `${prev.libgda6}` into its injected `preInstall` lines~~ **Superseded
  2026-10-22 by build evidence: no rewiring is needed.**
  nixpkgs' `extensionOverrides.nix` injects `prepend_search_path('${libgda6}/lib/girepository-1.0')`
  and resolves `libgda6` in the final package set, so the D2 override reaches the
  extension on its own. A first attempt added a `preInstall` that rewrote
  `prev.libgda6` to `final.libgda6` and guarded it with a grep; the guard failed
  the build with `copyous override: libgda prepend not found in lib/`, which is
  the proof: the pre-overlay path is never injected. The system closure built
  after removing it carries `libgda-6.0.0` at
  `/nix/store/2jhv5b2wknd6ic3577yjv6ab0d170v3c-libgda-6.0.0`, and the extension
  in that closure injects exactly that path in `lib/database/entryTracker.js` and
  `lib/preferences/dependencies/dependencies.js`.
- **D4: keep `database-backend='sqlite'` and the existing database.** With Gda
  loadable, the extension opens the current file on the next start. No dconf
  change and no migration.
- **D5: stop the updater from re-installing the user copy** (added 2026-10-22).
  Add `gnomeExtensions.disable-extension-updates` to
  `environment.systemPackages` and to the `org/gnome/shell` `enabled-extensions`
  dconf default. Without it, D1 is undone by the next EGO update check.
  - Rejected: re-delete the user copy by hand after each update. The staging
    directory proves the update arrives automatically, so this is a standing
    chore that fails silently in between.
  - Rejected: fake the store copy's metadata version above EGO's. It lies about
    the version in the Extensions app and has to be re-faked on every bump.
  - Rejected: make `extension-updates/` read-only or delete the Extensions app.
    Fragile, and the app ships inside the `gnome-shell` store path.
  - Rejected: move to 2.1.2 now with the terminal patch re-ported. nixpkgs has
    only v9, so it means fetching the EGO zip ourselves, re-porting
    `terminal-paste.patch` against 2.1.2's `clipboard.js` and rewriting the
    version guard. A follow-up, not this fix.

## Config diff (shape)

In the existing `nixpkgs.overlays` block:

```nix
      # Copyous loads Gda through GIRepository. The generated Gda-6.0.typelib
      # lists libxml2-2.0 as a prerequisite, but nixpkgs' libxml2 ships no
      # typelib (out and dev, 26.05 and unstable), so GJS aborts and the
      # extension falls back to memory ("Failed to load Gda"). Copyous only needs
      # the SQLite provider, so drop the XML include from the scanner. Drop this
      # override once libxml2 ships a typelib or libgda stops listing it; the
      # grep makes a libgda bump fail loudly.
      libgda6 = prev.libgda6.overrideAttrs (old: {
        postPatch = (old.postPatch or "") + ''
          grep -q "'libxml2-2.0'" libgda/meson.build || {
            echo "libgda override: libgda/meson.build no longer lists libxml2-2.0" >&2
            exit 1
          }
          sed -i "/'libxml2-2.0'/d" libgda/meson.build
        '';
      });
```

In the existing copyous override, the patch line is the only change:

```nix
            prev.gnomeExtensions.copyous.overrideAttrs (old: {
              patches = (old.patches or []) ++ [ ./copyous-terminal-paste/terminal-paste.patch ];
            });
```

## Execution

1. Apply D2 and D5 in `nix/configuration.nix`, run `nix-instantiate --parse`.
   D3 is not applied; see its revision above.
2. Build the system in the scratch mirror and confirm the new libgda and copyous
   paths are in the closure. Done: toplevel
   `/nix/store/8bx7kbamcp2jfvyxbsxix7ry77q36m2d-nixos-system-nixos-26.05.10402.1e8bc658fc98`.
3. Delete the user copy and the staging directory. Done 2026-10-22 02:32.
4. Reload the shell. `gnome-extensions disable/enable` does **not** work here: the
   running shell caches the extension's path and metadata, `ReloadExtension` on
   `org.gnome.Shell.Extensions` answers `Method ReloadExtension is not
   implemented`, the one on `org.gnome.Shell` answers `No such method`, and
   `Eval` returns `bs false ""` (unsafe mode off). A session restart is the only
   way, and the switch needs one anyway.
5. User runs `nix/update-nixos.sh switch`, then logs out and back in.
6. Verify (see TODO.md): no `Failed to load Gda` in the user journal, the loaded
   extension is the store copy, a copied string reaches the extension, and the
   terminal auto-paste inserts the copied text.

## Risks

- GNOME Shell keeps the deleted user copy in memory until the session restarts:
  between step 3 and step 5 the extension reports `State: ERROR` and clipboard
  history is off. The re-login clears it. Forcing a reload without one is not
  possible through D-Bus, as step 4 records.
- The copyous version guard still throws if a nixpkgs bump moves copyous past v9.
  That is intended and unchanged.
- The libgda override is tied to the `'libxml2-2.0'` line in
  `libgda/meson.build`. The guard makes the next bump fail with a clear message.
- The user copy v11 is newer than v9. After the swap, v11-only features are gone
  until nixpkgs packages v11. This is a deliberate trade for the terminal patch
  and managed state.
- If nixpkgs later ships a libxml2 typelib, the override becomes unnecessary. The
  comment names that drop condition.

## Follow-ups (not in this epic)

- Report the nixpkgs libgda typelib bug upstream: `Gda-6.0.typelib` requires
  `libxml2-2.0`, libxml2 provides no typelib, so `imports.gi.Gda` fails for any
  GJS consumer.
- When nixpkgs moves Copyous to v11, re-check issue #168 and PR #169 and re-port
  or delete `nix/copyous-terminal-paste/` as the existing guard instructs.
