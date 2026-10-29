#!/usr/bin/env bash
# binfmt_misc interpreter for type 2 AppImages on NixOS.
#
# Why this exists: nixpkgs' appimage-run unpacks the AppImage into
# ~/.cache/appimage-run/<sha256> and forwards every argument to AppRun, so the
# AppImage runtime flags are lost. A caller that extracts its own payload gets an
# empty directory instead of squashfs-root. Orca registers its CLI exactly that
# way, and unpacks app updates the same way, so both fail on this host.
#
# The stock AppImage runtime answers these flags itself. This wrapper answers the
# two that matter and hands everything else to appimage-run, which keeps the
# launch path identical to before. See .agents/plans/42-orca-appimage-extract.
set -euo pipefail

appimage="${1:?usage: appimage-binfmt <appimage> [args...]}"
shift

# Offset of the squashfs payload: the runtime appends it after the ELF section
# headers, so start of section headers + entry size * entry count. Same
# computation as nixpkgs' appimage-exec.sh.
payload_offset() {
	LC_ALL=C readelf -h "$1" | awk -F: '
		/Start of section headers/ { shoff = $2 }
		/Size of section headers/ { shentsize = $2 }
		/Number of section headers/ { shnum = $2 }
		END { print shoff + shentsize * shnum }
	'
}

if [[ "${1-}" == "--appimage-extract" ]]; then
	shift
	if (( $# > 0 )); then
		printf 'appimage-binfmt: --appimage-extract takes no arguments\n' >&2
		exit 2
	fi
	exec unsquashfs -q -no-progress -d squashfs-root -o "$(payload_offset "$appimage")" "$appimage"
fi

if [[ "${1-}" == "--appimage-offset" ]]; then
	payload_offset "$appimage"
	exit 0
fi

exec appimage-run "$appimage" "$@"
