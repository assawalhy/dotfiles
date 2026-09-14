#!/usr/bin/env bash
# desc: Beyond Compare (diff/merge tool)
# os: any
# check: command -v bcompare
# prio: p3
set -euo pipefail

# Installs Beyond Compare per the Scooter Software linux_install KB
# (https://www.scootersoftware.com/kb/linux_install), but via Scooter's
# apt/rpm repos rather than the KB's download URLs, which pin the exact
# version and rot. Repo setup is guarded so an existing install (e.g. the
# .deb postinst adds scootersoftware.sources itself) is never duplicated.

die() { printf 'beyond-compare: %s\n' "$*" >&2; exit 1; }

if [ "$(uname -s)" = Darwin ]; then
  command -v brew >/dev/null 2>&1 || die "Homebrew is missing -- run 00-homebrew.sh first"
  exec brew install --cask beyond-compare
fi

# The deb/rpm repos ship amd64 binaries only.
case "$(uname -m)" in
  x86_64) ;;
  *) die "Beyond Compare for Linux is amd64-only (this machine is $(uname -m))" ;;
esac

RPM_KEY=https://www.scootersoftware.com/RPM-GPG-KEY-scootersoftware

if command -v pacman >/dev/null 2>&1; then
  if command -v paru >/dev/null 2>&1; then AUR=paru
  elif command -v yay >/dev/null 2>&1; then AUR=yay
  else die "no AUR helper -- run 02-paru.sh first"
  fi
  "$AUR" -S --needed --noconfirm bcompare   # helpers sudo themselves

elif command -v apt-get >/dev/null 2>&1; then
  if [ ! -e /etc/apt/sources.list.d/scootersoftware.list ] &&
     [ ! -e /etc/apt/sources.list.d/scootersoftware.sources ]; then
    sudo curl -fsSLo /etc/apt/trusted.gpg.d/DEB-GPG-KEY-scootersoftware.asc \
      https://www.scootersoftware.com/DEB-GPG-KEY-scootersoftware.asc
    printf 'deb [arch=amd64] https://www.scootersoftware.com/debian/ bcompare5 non-free\n' |
      sudo tee /etc/apt/sources.list.d/scootersoftware.list >/dev/null
  fi
  sudo apt-get update
  sudo apt-get install -y bcompare

elif command -v dnf >/dev/null 2>&1; then
  sudo rpm --import "$RPM_KEY"
  if [ ! -e /etc/yum.repos.d/scootersoftware.repo ]; then
    cat <<EOF | sudo tee /etc/yum.repos.d/scootersoftware.repo >/dev/null
[scootersoftware]
name=Scooter Software
baseurl=https://www.scootersoftware.com/repos/rpm/bcompare5
enabled=1
gpgcheck=1
gpgkey=$RPM_KEY
EOF
  fi
  sudo dnf install -y bcompare

elif command -v zypper >/dev/null 2>&1; then
  # openSUSE is "partially supported" upstream: a missing gvfs-smb dep may
  # require breaking dependencies at install time (KB solution 2).
  sudo rpm --import "$RPM_KEY"
  if ! zypper lr -u 2>/dev/null | grep -q scootersoftware; then
    sudo zypper addrepo https://www.scootersoftware.com/repos/rpm/bcompare5 scootersoftware
  fi
  sudo zypper --non-interactive install bcompare

else
  die "no supported package manager (pacman/apt/dnf/zypper) found"
fi
