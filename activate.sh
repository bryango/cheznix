#!/bin/bash
# home-manager activation script

export PATH="$HOME/.nix-profile/bin:$PATH"

set -x

cd "$HOME" || exit
chezmoi init --ssh bryango/chezmoi

set +x
nix eval --raw cheznix#cheznix.inputs.home-attrs.outPath | cachix push chezbryan
nix profile list --json | jq > ~/.config/home-manager/profile.json

>&2 cat <<- EOF

	## to activate system config:
	sudo system-manager switch --flake "${FLAKE_CONFIG_URI%#*}"
EOF
