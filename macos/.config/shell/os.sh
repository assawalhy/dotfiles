# ~/.config/shell/os.sh -- macOS
#
# Sourced first by ~/.bash_profile. This file is provided by the macos/
# overlay; linux/ ships its own copy at the same path, so exactly one is ever
# linked and neither needs a `uname` branch.

DOTFILES_OS=macos

# ----------------------------------------------------------- homebrew ---

# Must run from here (which ~/.zshrc reaches via ~/.bash_profile) rather than
# from ~/.zprofile: /etc/zprofile runs path_helper, which reorders PATH and
# pushes /usr/bin ahead of /opt/homebrew/bin, clobbering anything set earlier.
for _b in /opt/homebrew/bin/brew /usr/local/bin/brew; do
  if [ -x "$_b" ]; then eval "$("$_b" shellenv)"; break; fi
done
unset _b

# ------------------------------------------------------------ aliases ---

alias o=open

# needs: brew install pngpaste
alias pasteimage='pngpaste -'

# no PRIMARY selection on macOS, so there is nothing to promote
alias imgptoc=:

# copyimage file.png   |   some-command | copyimage
copyimage() {
  local f="$1" tmp=""
  if [ -z "$f" ]; then
    tmp="$(mktemp -t copyimage)"; mv "$tmp" "$tmp.png"; tmp="$tmp.png"
    cat > "$tmp"; f="$tmp"
  fi
  f="$(cd "$(dirname "$f")" && pwd)/$(basename "$f")"
  osascript -e "set the clipboard to (read (POSIX file \"$f\") as «class PNGf»)"
  [ -n "$tmp" ] && rm -f "$tmp"
}

# ---------------------------------------------------------- functions ---

mem() {
  local total used page
  total="$(sysctl -n hw.memsize)"
  page="$(pagesize)"
  used="$(vm_stat | awk -v p="$page" '
    /Pages active/                     { gsub(/\./, "", $NF); s += $NF }
    /Pages wired down/                 { gsub(/\./, "", $NF); s += $NF }
    /Pages occupied by compressor/     { gsub(/\./, "", $NF); s += $NF }
    END { print s * p }')"
  awk -v u="$used" -v t="$total" 'BEGIN { printf "%.1f%%\n", u / t * 100 }'
}

# BSD ps: -m sorts by memory, and there is no --sort
memusage() {
  ps -axco comm,%mem -m | head -n "$(( ${1:-10} + 1 ))"
}

# $1 = major version (optional) -> prints JAVA_HOME
_jdk_home() {
  if [ -n "$1" ]; then
    /usr/libexec/java_home -v "$1"
  else
    /usr/libexec/java_home
  fi
}

# consumed by the ls aliases in ~/.bash_profile
_LS_COLOR_FLAG='-G'

# --------------------------------------------------------------- PATH ---

[ -d /usr/local/go/bin ] && PATH="$PATH:/usr/local/go/bin"
export PATH

# Optional: GNU coreutils without the g- prefix. Left commented on purpose --
# it silently changes ls/sed/date semantics for every script you run.
#   for _g in coreutils findutils gnu-sed gawk grep; do
#     [ -d "$HOMEBREW_PREFIX/opt/$_g/libexec/gnubin" ] &&
#       PATH="$HOMEBREW_PREFIX/opt/$_g/libexec/gnubin:$PATH"
#   done
#   export PATH
