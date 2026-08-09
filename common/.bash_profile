# ~/.bash_profile -- sourced by ~/.bashrc and ~/.zshrc, never executed.
#
# seek help: man info apropos whatis tldr

# Platform-specific aliases, functions and PATHs. Provided by the linux/ or
# macos/ overlay -- whichever one was linked. Must come first: it sets
# $_LS_COLOR_FLAG and puts homebrew on PATH.
[ -f "$HOME/.config/shell/os.sh" ] && . "$HOME/.config/shell/os.sh"

# set PATH so it includes user's private bin if it exists
[ -d "$HOME/bin" ] && export PATH="$HOME/bin:$PATH"
[ -d "$HOME/.local/bin" ] && export PATH="$HOME/.local/bin:$PATH"

# ------------------------------------
#              aliases
# ------------------------------------

alias pn=pnpm
alias r="ranger"
alias lg=lazygit
alias lzd=lazydocker
alias sail='sh $([ -f sail ] && echo sail || echo vendor/bin/sail)'
alias prgs='printf "$(git status)"'

alias yws="yarn workspace"
alias ywsf="yarn workspaces foreach"

# exa is unmaintained; prefer its fork eza, and fall back to the system ls
# with whatever colour flag this platform uses (--color=auto vs -G).
if command -v eza >/dev/null 2>&1;   then _LS=eza
elif command -v exa >/dev/null 2>&1; then _LS=exa
else                                      _LS=''
fi
if [ -n "$_LS" ]; then
  alias ls="$_LS"
  alias l="$_LS -la --icons --sort=type"
  alias ll="$_LS -l --icons --sort=type"
else
  alias ls="ls $_LS_COLOR_FLAG"
  alias l="ls -la $_LS_COLOR_FLAG"
  alias ll="ls -l $_LS_COLOR_FLAG"
fi
unset _LS

# Setting fd as the default source for fzf (Debian ships it as `fdfind`)
if command -v fd >/dev/null 2>&1;       then _FD=fd
elif command -v fdfind >/dev/null 2>&1; then _FD=fdfind
else                                         _FD=''
fi
if [ -n "$_FD" ]; then
  export FZF_DEFAULT_COMMAND="$_FD --strip-cwd-prefix"
  # To apply the command to CTRL-T as well
  export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
fi
unset _FD

# ------------------------------------
#       default common setting
# ------------------------------------

export NEWT_COLORS='
    root=,red
    title=red,white
    textbox=,white
    window=,white
    border=black,white
    button=white,red
    listbox=,white
    actsellistbox=white,red
    compactbutton=,white
    actlistbox=white,red
'

# ------------------------------------
#           default apps
# ------------------------------------

export EDITOR=nvim

# ------------------------------------
#          my own scripts
# ------------------------------------

# mem() and memusage() are platform-specific -- see ~/.config/shell/os.sh

function z() {
  zellij --layout ~/.config/zellij/layouts/layout1.yaml
}

# lg()
# {
#   export LAZYGIT_NEW_DIR_FILE=~/.lazygit/newdir
#   lazygit "$@"
#   if [ -f $LAZYGIT_NEW_DIR_FILE ]; then
#     cd "$(cat $LAZYGIT_NEW_DIR_FILE)"
#     rm -f $LAZYGIT_NEW_DIR_FILE > /dev/null
#   fi
# }

# list all + exclude
function lae() {
  if [ "$#" -lt 2 ]; then
    echo invalid number of arguments >&2
    return 2
  fi
  local dir=$1; shift
  local patterns="\\($1\\)"; shift
  while [ "$#" -gt 0 ]; do
    patterns+="\\|\\($1\\)"; shift
  done
  # list the first arg, and exclude the reset
  /bin/ls -A "$dir" | sed "/^$patterns$/ d" | awk "{ print \"$dir/\"\$0 }"
}

# -----------------------------------------
#        C/C++: watch and run
# -----------------------------------------

GXX="-DSAWALHY"

function ensure-file() {
  set -e
  local err
  local file_ext
  local file_path
  local real_ext
  local bin

  file_path="$1"; shift

  while (($#)); do
    file_ext="$1"; shift
    real_ext="${file_path: -$((${#file_ext} + 1))}" # +1 for the dot
    if [ "$real_ext" = ".$file_ext" ]; then
      bin="${file_path:0:-${#real_ext}}"
      break
    fi
  done

  if [ ! "$bin" ]; then
    if [ -f "$file_path" ]; then
      echo "file is not supported for this command: $file" >&2
    else
      echo "file not found: $file" >&2
    fi
    return 1
  fi

  echo "$bin"
}

function rgcc() {
  local bin
  local file="$1"
  bin="$(ensure-file "$file" c)"
  if [ ! "$bin" ]; then return 1; fi
  bin="$(realpath "$bin")"

  gcc "$GXX" "$file" -o "$bin" && "$bin" "$@"
}

function wgcc() {
  local bin
  local file="$1"
  bin="$(ensure-file "$file" c)"
  if [ ! "$bin" ]; then return 1; fi
  bin="$(realpath "$bin")"

  nodemon -w "$file" -x gcc "$GXX" "$file" -o "$bin" "&&" "$bin" "$@"
}

function rg++() {
  local bin
  local file="$1"
  bin="$(ensure-file "$file" cc cpp)"
  if [ ! "$bin" ]; then return 1; fi
  bin="$(realpath "$bin")"

  shift
  g++ $GXX "$file" -o "$bin" && "$bin" "$@"
}

function wg++() {
  # watch and compile, then execute the code
  local bin
  local file="$1"
  bin="$(ensure-file "$file" cc cpp)"
  if [ ! "$bin" ]; then return 1; fi
  bin="$(realpath "$bin")"

  shift
  nodemon -w "$file" -x g++ "$GXX" "$file" -o "$bin" "&&" "$bin" "$@"
}

# The JDK location differs per platform, so it comes from _jdk_home() in
# ~/.config/shell/os.sh. Both accept an optional leading -<version>, e.g.
#   rjava -17 Main.java
function rjava() {
  local jdk_ver='' bin file JDK java javac

  case "$1" in -[0-9]*) jdk_ver="${1#-}"; shift ;; esac

  file="$1"; shift
  JDK="$(_jdk_home "$jdk_ver")" || return 1
  java="$JDK/bin/java"
  javac="$JDK/bin/javac"

  bin="$(ensure-file "$file" java)"
  if [ ! "$bin" ]; then return 1; fi

  "$javac" $JC_OPTIONS "$file" &&
  "$java" $JC_OPTIONS -cp "$(dirname "$bin")" "$(basename "$bin")" "$@"
}

function wjava() {
  local jdk_ver='' bin file JDK java javac

  case "$1" in -[0-9]*) jdk_ver="${1#-}"; shift ;; esac

  file="$1"; shift
  JDK="$(_jdk_home "$jdk_ver")" || return 1
  java="$JDK/bin/java"
  javac="$JDK/bin/javac"

  bin="$(ensure-file "$file" java)"
  if [ ! "$bin" ]; then return 1; fi

  nodemon -w "$file" -e c -x \
    "$javac" $JC_OPTIONS "$file" "&&" \
    "$java" $JC_OPTIONS -cp "$(dirname "$bin")" "$(basename "$bin")" "$@"
}

function wpy() {
  local bin
  local file=$1; shift
  bin="$(ensure-file "$file" py)"
  if [ ! "$bin" ]; then return 1; fi

  nodemon -w "$file" -e c -x python "$file"
}

# ----------------------------------------------------------
# -----------            PATHs          --------------------
# ----------------------------------------------------------
#
# Platform-specific entries (/snap/bin, homebrew, ...) live in
# ~/.config/shell/os.sh. Only cross-platform, $HOME-relative ones belong here.

export PATH="$HOME/.cargo/bin:$PATH"
export PATH="$HOME/.volta/bin:$PATH"

# bun
[ -s "$HOME/.bun/_bun" ] && . "$HOME/.bun/_bun"
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

export PATH="$PATH:$HOME/.foundry/bin"

# php, composer, ...
export PATH="$PATH:$HOME/.config/composer/vendor/bin"

# written by the rust/uv installers; absent on a fresh machine
[ -f "$HOME/.local/bin/env" ] && . "$HOME/.local/bin/env"
export PATH="$HOME/.local/bin:$PATH"
