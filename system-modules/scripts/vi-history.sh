#!/bin/sh
# vi-history: open the local shell history file in vi

alias vi-history=vi_history
vi_history() {
  history_path=""
  if [ -n "$ZSH_VERSION" ] && [ -r "$HOME/.zsh_history" ]; then
    history_path="$HOME/.zsh_history"
  elif [ -n "$BASH_VERSION" ] && [ -r "$HOME/.bash_history" ]; then
    history_path="$HOME/.bash_history"
  fi
  if [ -n "$history_path" ]; then
    vi '+exe "normal G\<Up>"' "$history_path"
  else
    return 1
  fi
}
