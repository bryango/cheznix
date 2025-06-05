#!/bin/bash
# home-manager activation script

export PATH="$HOME/.nix-profile/bin:$PATH"

CHEZNIX="$HOME/.config/home-manager"

# the following commands will be echoed
set -x

cd "$HOME" || exit 1
chezmoi init --ssh bryango/chezmoi --branch dev

# ensure that `home-attrs` is cached
nix eval --raw cheznix#cheznix.inputs.home-attrs.outPath | cachix push chezbryan &

chores
verify downstream overrides of upstream files
if [[ $HOSTNAME == memoriam ]]; then
  git diff --color=always --no-index \
    {/run/current-system/sw/share/zsh/5.9/functions,~/.zsh_profiles/completions}/_networksetup || true
fi

# the following commands will be silent
set +x

# note that $hmConfigRef is exported from ./modules/home-setup.nix
# shellcheck disable=2154
profile_hash=$(echo "$hmConfigRef" | sha1sum | head -c 5)
nix profile list --json | jq > "$CHEZNIX/profile-${profile_hash}.json"

>&2 echo
>&2 printf "## installing git hooks ... "
pushd "$CHEZNIX/.git/hooks" &>/dev/null || exit 1
ln -sf ../../pre-commit pre-commit
popd &>/dev/null || exit 1
>&2 echo "completed."

if [[ $OSTYPE == linux* ]];
then >&2 cat <<- EOF

	## to activate system config:
	sudo system-manager switch --flake "${FLAKE_CONFIG_URI%#*}"
EOF
fi
