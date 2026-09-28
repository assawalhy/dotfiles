#!/bin/bash
# ~/.profile: executed by the command interpreter for login shells.
# This file is not read by bash(1), if ~/.bash_profile or ~/.bash_login
# exists.

if [ -n "$BASH_VERSION" ]; then
  if [ -f "$HOME/.bashrc" ]; then
    . "$HOME/.bashrc"
  fi
fi

if [ -d "$HOME/bin" ]; then
  PATH="$HOME/bin:$PATH"
fi

if [ -d "$HOME/.local/bin" ]; then
  PATH="$HOME/.local/bin:$PATH"
fi

# xrandr layout for the desktop; harmless to skip on headless boxes and laptops
if [ -n "$DISPLAY" ] && command -v screenlayouts >/dev/null 2>&1; then
  screenlayouts
fi

# VOLTA_HOME/PATH and .local/bin/env are set by ~/.bash_profile
