#!/usr/bin/env bash
# desc: go (golang)
# os: any
# check: command -v go
# prio: p2
set -euo pipefail

GO_VERSION="${GO_VERSION:-1.24.1}"

# Install go if missing
if ! command -v go >/dev/null 2>&1; then
  ARCH="$(uname -m)"
  case "$ARCH" in
    x86_64)  ARCH=amd64 ;;
    aarch64) ARCH=arm64 ;;
    armv7l)  ARCH=armv6l ;;
    *) echo "unsupported arch: $ARCH" >&2; exit 1 ;;
  esac

  TARBALL="go${GO_VERSION}.linux-${ARCH}.tar.gz"
  URL="https://go.dev/dl/${TARBALL}"

  tmpdir="$(mktemp -d)"
  trap 'rm -rf "$tmpdir"' EXIT

  echo "→ downloading go ${GO_VERSION} (${ARCH})"
  curl -fsSL -o "${tmpdir}/${TARBALL}" "$URL"

  echo "→ installing to /usr/local/go"
  sudo tar -C /usr/local -xzf "${tmpdir}/${TARBALL}"

  # Ensure /usr/local/go/bin is in PATH for the rest of this session
  export PATH="/usr/local/go/bin:$PATH"
fi

# Persist PATH for future shells (idempotent). Always run, even when go was
# already present, so a toolchain installed outside this script still gets its
# bin dirs on PATH. ~/.bash_profile is the shared config here: ~/.zshrc sources
# it, so one write covers bash and zsh.
PROFILE="$HOME/.bash_profile"
[ -f "$PROFILE" ] || : > "$PROFILE"

PROFILE_LINE='export PATH="/usr/local/go/bin:$PATH"'
grep -qF '/usr/local/go/bin' "$PROFILE" || echo "$PROFILE_LINE" >> "$PROFILE"

# Set GOPATH and persist it
export GOPATH="${GOPATH:-$HOME/go}"
GO_PATH_LINE="export GOPATH=\"\$HOME/go\""
grep -qF 'GOPATH' "$PROFILE" || echo "$GO_PATH_LINE" >> "$PROFILE"
export PATH="$GOPATH/bin:$PATH"
GO_BIN_PATH_LINE='export PATH="$GOPATH/bin:$PATH"'
grep -qF 'GOPATH/bin' "$PROFILE" || echo "$GO_BIN_PATH_LINE" >> "$PROFILE"

echo "✓ go ${GO_VERSION} ready"
go version
