# ~/.bashrc

PS1='[\u@\h \W]\$ '

[[ $- != *i* ]] && return

export GPG_TTY=$(tty)

##############---------------------------------
## import other script files
##############---------------------------------

# also sets the ls aliases and the fzf/fd defaults
[ -f ~/.bash_profile ] && . ~/.bash_profile

[ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"

export GOPATH="$HOME/go"
export PATH="$GOPATH/bin:$PATH"
