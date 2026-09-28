
export ZSH="$HOME/.oh-my-zsh"

ZSH_THEME="flazz"
ZSH_THEME="eastwood"
ZSH_THEME="gnzh"
ZSH_THEME="fishy"
ZSH_THEME="arrow"

plugins=(git fzf)

source $ZSH/oh-my-zsh.sh

bindkey -M menuselect '^[[Z' reverse-menu-complete

##############---------------------------------
## my own config
##############---------------------------------

export GPG_TTY=$(tty)

# macOS tools default to ~/Library/Application Support for config; XDG-aware
# tools (lazygit, etc.) honor XDG_CONFIG_HOME, so point it at the linked
# dotfiles in ~/.config (a no-op on Linux, where that is the default anyway).
export XDG_CONFIG_HOME="$HOME/.config"

# also sets the ls aliases and the fzf/fd defaults
[ -f ~/.bash_profile ] && . ~/.bash_profile

export GOPATH="$HOME/go"
export PATH="$GOPATH/bin:$PATH"

_ensure_gcloud_adc() {
  gcloud auth application-default print-access-token >/dev/null 2>&1 \
    || gcloud auth application-default login
}

# Unalias first: zsh resolves aliases at parse time, so re-sourcing this file
# into a shell that still holds the old `alias pgclaude=` fails with
# "defining function based on alias". The pgclaude function is not defined in
# that case, and the old alias runs gcloud login unconditionally.
unalias pgclaude 2>/dev/null
pgclaude() { _ensure_gcloud_adc && claude "$@" }

alias pgkiro='gcloud auth application-default login && kiro-cli'

eval "$(uv generate-shell-completion zsh)"

