# ~/.bashrc

PS1='[\u@\h \W]\$ '

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

export GPG_TTY=$(tty)

##############---------------------------------
## import other script files
##############---------------------------------

# also sets the ls aliases and the fzf/fd defaults
[ -f ~/.bash_profile ] && . ~/.bash_profile

. "$HOME/.cargo/env"

# Go
export GOPATH="$HOME/go"
export PATH="$GOPATH/bin:$PATH"
