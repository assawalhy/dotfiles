#!/usr/bin/env bash
# desc: opencode auto-compaction tuning (keep + buffer)
# os: any
# check: jq -e '.compaction.keep.tokens == 30000 and .compaction.buffer == 65536' "$HOME/.config/opencode/opencode.json" >/dev/null 2>&1 || { [ -f "$HOME/.config/opencode/opencode.jsonc" ] && jq -e '.compaction.keep.tokens == 30000 and .compaction.buffer == 65536' "$HOME/.config/opencode/opencode.jsonc" >/dev/null 2>&1; }
# requires: jq
# prio: p2
#
# Compaction is already on by default (compaction.auto = true), so this step does
# not switch it on -- it pins it, and sizes the two knobs that decide *when*
# compaction fires:
#
#   auto         true      pin explicitly so no later edit silently disables it
#   keep.tokens  30000    recent conversation preserved beside the summary; the
#                         15000 default is thin next to a 512k input ceiling
#   buffer       65536    headroom kept free below the model's limit
#
# Why buffer is an explicit number rather than the 10% default: the docs define
# it only as a percentage of "the limit" and do not say which limit. This
# machine's model reports limit.context = 1048576 but limit.input = 524288, so
# a 10% buffer computed against context would arm far above the ceiling the
# provider actually accepts. 65536 is sized against limit.input instead.
#
# Key names are the V2 ones (keep.tokens, buffer). The published schema at
# https://opencode.ai/config.json is still V1-shaped -- it declares prune,
# tail_turns, preserve_recent_tokens and reserved, and rejects keep/buffer as
# unknown properties. That is why no $schema is added here. See
# https://opencode.ai/v2/docs/compaction/
#
# jq writes through a temp file and `mv`, which replaces a symlink with a
# regular file -- another reason opencode.json is seeded by 68 rather than
# symlinked by link-files.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATES="$(cd "$SCRIPT_DIR/../templates" && pwd)"

command -v jq >/dev/null 2>&1 || {
  printf '  - jq missing, cannot set opencode compaction\n' >&2
  exit 0
}

# Reuse 68's precedence: an existing config wins, otherwise default to
# opencode.json so 68's template and this step agree on the same path.
cfg=""
for f in "$HOME/.config/opencode/opencode.jsonc" \
         "$HOME/.config/opencode/opencode.json" \
         "$HOME/.config/opencode.jsonc" \
         "$HOME/.config/opencode.json"; do
  [ -e "$f" ] && { cfg="$f"; break; }
done
[ -n "$cfg" ] || cfg="$HOME/.config/opencode/opencode.json"

if [ ! -e "$cfg" ]; then
  # 69 can run without 68 (different prio tier); seed first so jq has a target.
  if [ -f "$TEMPLATES/opencode.json" ]; then
    mkdir -p "$(dirname "$cfg")"
    cp "$TEMPLATES/opencode.json" "$cfg"
    chmod 600 "$cfg" 2>/dev/null || true
    printf '  + %s: seeded from template\n' "$cfg"
  else
    printf '  - %s missing and no template to seed it; run 68-opencode-config.sh first\n' "$cfg" >&2
    exit 0
  fi
fi

tmp="$(mktemp "${TMPDIR:-/tmp}/opencode-compaction.XXXXXX")"
if ! jq --indent 2 \
  '.compaction = {"auto": true, "keep": {"tokens": 30000}, "buffer": 65536}' \
  "$cfg" > "$tmp" 2>/dev/null; then
  printf '  - %s: not valid JSON for jq; left unchanged\n' "$cfg" >&2
  rm -f "$tmp"
  exit 0
fi
mv "$tmp" "$cfg"
printf '  + %s: compaction set (auto, keep 30000, buffer 65536)\n' "$cfg"
