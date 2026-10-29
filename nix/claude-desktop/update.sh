#!/usr/bin/env bash
set -euo pipefail

repo=https://downloads.claude.ai/claude-desktop/apt/stable
nixfile="$(cd "$(dirname "$0")" && pwd)/default.nix"

latest() {
  curl -fsSL "$repo/dists/stable/main/binary-$1/Packages" |
    awk '/^Version:/{v=$2} /^SHA256:/{h=$2} END{print v, h}'
}

read -r version amd64_hex < <(latest amd64)
read -r arm64_version arm64_hex < <(latest arm64)
if [[ "$version" != "$arm64_version" ]]; then
  echo "amd64 ($version) and arm64 ($arm64_version) versions differ" >&2
  exit 1
fi

current="$(sed -n 's/^  version = "\(.*\)";/\1/p' "$nixfile")"
if [[ "$current" == "$version" ]]; then
  echo "claude-desktop is already $version"
  exit 0
fi

sri() { nix hash convert --hash-algo sha256 --to sri "$1"; }
amd64_sri="$(sri "$amd64_hex")"
arm64_sri="$(sri "$arm64_hex")"

perl -0pi -e "
  s{(debArch = \"amd64\";\s*hash = \")[^\"]*}{\${1}$amd64_sri};
  s{(debArch = \"arm64\";\s*hash = \")[^\"]*}{\${1}$arm64_sri};
  s{^  version = \"[^\"]*\";}{  version = \"$version\";}m;
" "$nixfile"

echo "claude-desktop $current -> $version"
