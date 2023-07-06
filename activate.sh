#!/bin/bash
# home-manager activation script

export PATH="$HOME/.nix-profile/bin:$PATH"

set -x
cd "$HOME" || exit

chezmoi init --ssh bryango/chezmoi
