#!/bin/bash
# home-manager activation script

export PATH="$HOME/.nix-profile/bin:$PATH"

set -x
nix profile list --json | jq > ~/.config/home-manager/profile.json
cd "$HOME" || exit

chezmoi init --ssh bryango/chezmoi
