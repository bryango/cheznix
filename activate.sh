#!/bin/bash
# home-manager activation script

export PATH="$HOME/.nix-profile/bin:$PATH"

CHEZNIX="$HOME/.config/home-manager"

# the following commands will be echoed
set -x

cd "$HOME" || exit 1
chezmoi init --ssh bryango/chezmoi

# ensure that `home-attrs` is cached
nix eval --raw cheznix#cheznix.inputs.home-attrs.outPath | cachix push chezbryan &

# chores
# verify downstream overrides of upstream files
git diff --color=always --no-index \
  {/usr/share/zsh/site-functions,~/.zsh_profiles/completions}/_systemctl || true

# the following commands will be silent
set +x
nix profile list --json | jq > "$CHEZNIX/profile.json"

>&2 echo
>&2 printf "## installing git hooks ... "
pushd "$CHEZNIX/.git/hooks" &>/dev/null || exit 1
ln -sf ../../pre-push pre-push
popd &>/dev/null || exit 1
>&2 echo "completed."

>&2 cat <<- EOF

	## to activate system config:
	sudo system-manager switch --flake "${FLAKE_CONFIG_URI%#*}"
EOF
