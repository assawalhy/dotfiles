# Epic 16 — Opencode auto-compaction

## Goal

Make opencode's automatic compaction explicit and correctly sized, and make it
survive a fresh machine via the repo's existing jq-patch mechanism.

## Findings (researched, not assumed)

1. **`compaction.auto` already defaults to `true` in V2.** `opencode api get
   /api/config` shows the effective config has no `compaction` block, so
   auto-compaction is already on. There is nothing to enable — the user rarely
   compacts manually because they do not need to.

2. **The model's window is not what it looks like.** `space-bunny-free`
   (providers `opencode-go` and `opencode`) reports `limit.context = 1048576`
   but `limit.input = 524288`. Default `buffer` is "10% of the limit" and the
   docs do not say *which* limit. See Risks.

3. **The published schema is V1-shaped.** `https://opencode.ai/config.json`
   declares `auto`, `prune`, `tail_turns`, `preserve_recent_tokens`,
   `reserved` — and `additionalProperties: false`. It contains neither `keep`
   nor `buffer`, which are the V2 keys. `https://opencode.ai/v2/config.json` is
   404. Adding `$schema` would make the editor flag the correct V2 keys.

4. **Provider-side compaction is unavailable.** `settings.compaction.type:
   native` is OpenAI Responses models only; this box uses
   `@opencode/ai/providers/openai-compatible` against `opencode.ai/zen`. Only
   OpenCode's own `summary` compaction applies.

5. **`jp` cannot substitute for `jq`.** Verified: `jp --indent 2` exits with
   `flag provided but not defined: -indent`.

6. **`jq` is required but absent from `setup/packages.list`.**
   `setup/agent-tools.sh:56` needs real `jq` for every MCP key it writes, but
   the catalog only ships `jp` (`check:jp p2`). On this NixOS box jq came from
   the system, so the gap is invisible; on a machine bootstrapped from this
   repo, `context7` and `zvec_grep` silently no-op with
   `- jq missing, cannot edit`.

## Approach

```
.agents/plans/16-opencode-auto-compaction/   PLAN.md + TODO.md   (new)
setup/steps/68-opencode-compaction.sh                          (new)
setup/packages.list                          + jq               (1 line)
~/.config/opencode/opencode.json             patched live, NOT committed
```

The step locates the config with the same precedence `agent-tools.sh` uses
(`.config/opencode/opencode.jsonc` → `opencode.json` → `.config/opencode.jsonc`
→ `.config/opencode.json`), creates it if missing, then assigns `.compaction`
with jq so every other key survives verbatim. `# check:` makes it a no-op once
the values are in place.

## Decisions

- **V2 keys `keep.tokens` + `buffer`**, not the V1 keys in the published
  schema — the schema is documented as V1 and no V2 schema exists.
- **Omit `$schema`** — it would flag the valid V2 keys as errors.
- **`keep.tokens: 30000`** — the 15k default is thin next to a 512k input
  ceiling. Rejected 60k+: eats headroom and compacts more often.
- **`buffer: 65536`** — sized against `limit.input` (512k), so compaction arms
  near 448k, leaving room for one more turn plus the compaction request.
  Rejected the 10% default (may arm past 512k) and 128k (over-compacts).
- **New setup step, not `agent-tools.sh`** — that file's stated contract is
  third-party tool installs fanned out to every harness; compaction tuning is
  a preference, not a tool, and adding it would need a fake `agent-tool` row.
- **`jq` primary, no `jp` fallback** — `jp` is not CLI-compatible (finding 5).
  Degrade with a message, exactly as `agent-tools.sh` already does.
- **Add `jq` to `setup/packages.list`** — the new step needs it and
  `agent-tools.sh` already silently depends on it. Without this the step is a
  no-op on a fresh machine.
- **Model `limit` pinning deferred to phase 2** — see Risks.

## Risks

- **`buffer`'s base limit is undocumented.** If it is a percentage of
  `limit.context` (1M) rather than `limit.input` (512k), then 65536 still
  leaves the trigger above 512k, auto-compaction would never arm on its own,
  and sessions would fall back to the "rejected as too long → compact → retry
  once" recovery path. Correct under either reading only if the trigger is
  input-based. Phase 2, if observation shows late compaction: pin
  `providers.<id>.models.<id>.limit` so the base is unambiguous.
- **Compaction is lossy.** A larger `buffer` means more frequent compaction and
  a summary rewritten more often. 64k/30k is a middle setting.
- **The background service caches config.** A restart may be needed for a live
  change to take effect.
- **`setup/packages.list` ordering/tier** — `jq` belongs at `p1` as a runtime
  dependency of two setup scripts; confirm the tier with the user if the
  existing p1 block does not obviously cover it.
