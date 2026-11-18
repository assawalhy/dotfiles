#!/usr/bin/env bash
set -euo pipefail

repo=https://mega.nz/linux/repo/xUbuntu_24.04/amd64
debarch=amd64
nixfile="$(cd "$(dirname "$0")" && pwd)/default.nix"

latest() {
  curl -fsSL "$repo/" | grep -o "megasync_[0-9][^\"<]*_${debarch}\.deb" | sort -uV | tail -1
}

deb="$(latest)"
if [[ -z "$deb" ]]; then
  echo "no megasync ${debarch} deb in $repo" >&2
  exit 1
fi

version="${deb#megasync_}"
version="${version%_${debarch}.deb}"

current="$(sed -n 's/^  version = "\(.*\)";/\1/p' "$nixfile")"
if [[ "$current" == "$version" ]]; then
  echo "megasync is already $version"
  exit 0
fi

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
curl -fsSL -o "$tmp/$deb" "$repo/$deb"
hash="$(nix hash file --type sha256 --sri "$tmp/$deb")"

perl -0pi -e "
  s{(debArch = \"${debarch}\";\s*hash = \")[^\"]*}{\${1}$hash};
  s{^  version = \"[^\"]*\";}{  version = \"$version\";}m;
" "$nixfile"

echo "megasync $current -> $version"
