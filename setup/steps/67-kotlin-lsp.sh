#!/usr/bin/env bash
# desc: kotlin-lsp (official JetBrains Kotlin language server)
# os: linux
# check: test -x "${XDG_DATA_HOME:-$HOME/.local/share}/kotlin-lsp/current/bin/intellij-server"
# prio: p2
set -euo pipefail

# JetBrains' official Kotlin LSP (IntelliJ-based); fwcd's
# kotlin-language-server cannot read Kotlin 2.3 metadata and its Kotlin
# version is frozen at 2.1.0 (.agents/plans/11-kotlin-lsp/PLAN.md).
# Version-pinned: bump VER and SHA256 together; the checksum guards the
# download. macOS is intentionally excluded (# os: linux): JetBrains ships
# .sit installers there, not this tarball.
VER=263.4702.0
SHA256=1e11d2e5fefbf9ea215ad8dd6be95f2222897cd086e8cb7a661a52084a590405
URL="https://download-cdn.jetbrains.com/language-server/kotlin-server/$VER/kotlin-server-$VER.tar.gz"

DEST="${XDG_DATA_HOME:-$HOME/.local/share}/kotlin-lsp"
[ -x "$DEST/current/bin/intellij-server" ] && exit 0

case "$(uname -m)" in
  x86_64) ;;
  *) echo "kotlin-lsp: only x86_64 is verified for this tarball (aarch64 exists but is untested here); nvim falls back to kotlin-language-server" >&2; exit 1 ;;
esac

command -v curl >/dev/null || { echo "kotlin-lsp: curl is required" >&2; exit 1; }

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
curl -fsSL -o "$tmp/kotlin-server.tar.gz" "$URL"
echo "$SHA256  $tmp/kotlin-server.tar.gz" | sha256sum -c - >/dev/null

mkdir -p "$DEST/$VER"
tar -xzf "$tmp/kotlin-server.tar.gz" -C "$DEST/$VER" --strip-components=1
# The heap ceiling stays JetBrains' own (bin/intellij-server.vmoptions): the
# file is not read from the launcher's environment in a way we can override,
# and observed RSS is ~1 GiB anyway - config/memory.lua gives kotlin_lsp its
# own RAM floor instead of trying to cap the JVM.
ln -sfn "$DEST/$VER" "$DEST/current"
echo "kotlin-lsp $VER -> $DEST/current"
