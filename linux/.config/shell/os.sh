# ~/.config/shell/os.sh -- Linux
#
# Sourced first by ~/.bash_profile. This file is provided by the linux/
# overlay; macos/ ships its own copy at the same path, so exactly one is ever
# linked and neither needs a `uname` branch.

DOTFILES_OS=linux

# ------------------------------------------------------------ aliases ---

alias o=xdg-open
alias alacritty="LIBGL_ALWAYS_SOFTWARE=1 alacritty"

alias copyimage="xclip -sel clip -t image/png"
alias pasteimage="xclip -sel clip -t image/png -o"
alias imgptoc="xclip -sel p -t image/png -o | xclip -sel clip -t image/png"

# pbcopy/pbpaste are native on macOS; provide them here so scripts written
# against them are portable. bin/clip picks the right backend at runtime.
if ! command -v pbcopy >/dev/null 2>&1; then
  pbcopy()  { clip; }
  pbpaste() { clip -o; }
fi

# ---------------------------------------------------------- functions ---

mem() { free | awk '/^Mem/ { print $3/$2*100"%" }'; }

memusage() {
  ps -axch -o cmd,%mem --sort=-%mem | head -n "${1:-10}"
}

# $1 = major version (optional) -> prints JAVA_HOME
_jdk_home() {
  if [ -n "$1" ]; then
    printf '/usr/lib/jvm/java-%s-openjdk\n' "$1"
  else
    printf '/usr/lib/jvm/default\n'
  fi
}

# consumed by the ls aliases in ~/.bash_profile
_LS_COLOR_FLAG='--color=auto'

# ---------------------------------------------------------- environment

# WSL2 with VcXsrv on Windows to show the GUI
# export DISPLAY=$(grep -m 1 nameserver /etc/resolv.conf | awk '{print $2}'):0
if [ -n "$WSL_DISTRO_NAME" ]; then
  export DISPLAY=$(ip route show | grep 'default via' | awk '{ print $3 }'):0
fi

# --------------------------------------------------------------- PATH ---

[ -d /snap/bin ]                  && PATH="/snap/bin:$PATH"
[ -d /usr/lib/cargo/bin ]         && PATH="/usr/lib/cargo/bin:$PATH"
[ -d /opt/nvim-linux-x86_64/bin ] && PATH="/opt/nvim-linux-x86_64/bin:$PATH"
[ -d /usr/local/go/bin ]          && PATH="$PATH:/usr/local/go/bin"
export PATH
