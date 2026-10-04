# TODO — Opencode auto-compaction

> **Superseded by epic 18.** Every item below shipped there, under step
> `69-opencode-compaction.sh` (not `68`, which epic 18 uses for config seeding)
> and the live config patch. Kept as the record of the original findings; the
> open item at the bottom is genuinely still open.

## Findings this epic produced

- `compaction.auto` already defaults to `true` in V2 — nothing to "switch on".
- `space-bunny-free` reports `limit.context = 1048576` but
  `limit.input = 524288`, and the default `buffer` is "10% of the limit" with
  the docs not saying *which* limit.
- The published schema at `https://opencode.ai/config.json` is V1-shaped
  (`prune`, `tail_turns`, `preserve_recent_tokens`, `reserved`) and rejects the
  V2 keys `keep.tokens` / `buffer`. `https://opencode.ai/v2/config.json` is 404.
  Hence no `$schema` in the config.

## Shipped (in epic 18)

- [x] `jq` added to `setup/packages.list` at `p1`
- [x] `setup/steps/69-opencode-compaction.sh` — sets
      `{auto: true, keep: {tokens: 30000}, buffer: 65536}` via jq, seeds from the
      template if the config is missing, leaves corrupt JSON untouched, degrades
      with exit 0 when `jq` is absent
- [x] `bash -n` clean; the `# check:` header returns the right answer in all four
      states tested
- [x] Verified against throwaway `HOME`s: works standalone, preserves
      `default_agent` / `permissions` / `mcp`
- [x] Patched the live `~/.config/opencode/opencode.json`
- [x] `opencode api get /api/config` reports the block; the running service
      picked it up **without a restart**
- [x] Unrelated keys (`default_agent`, `permissions`, `mcp.zvec_grep`) intact;
      step 68 does not reformat the file afterwards
- [x] `setup-os --list` offers the step and reports it done

## Still open

- [ ] **Phase 2 trigger.** `buffer`'s base limit is undocumented. If compaction
      is ever seen arming only *after* a provider "too long" rejection, the
      buffer is being read against `limit.context` (1M) rather than
      `limit.input` (512k). Fix by pinning
      `providers.<id>.models.<id>.limit` so the base is unambiguous. Not
      triggered so far — worth watching in a long session.
- [ ] `default_agent: awesome-agent` and the `~/MEMORY.md` permissions block are
      hand-maintained. They are now seeded from `setup/templates/opencode.json`,
      so they survive a fresh machine — but they still live only in this repo,
      not in any per-machine config.