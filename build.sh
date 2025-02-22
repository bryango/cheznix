#!/bin/bash
# build home configs

set -x
cd "$(dirname "$0")" || exit

IFS=" " read -r -a allConfigs <<< "$(nix eval --raw --impure --expr \
  "with builtins; attrNames (getFlake path:$PWD).checkConfigurations.\${currentSystem}" \
  --apply toString \
  | xargs  ## space separated lists
)"

for oneConfig in "${allConfigs[@]}"; do
  # same command for `home-manager` and `darwin-rebuild`
  nix run . -- build -v --flake ".#$oneConfig" "$@"
done

# work around: build a home-manager configuration for darwin
# this logic better exist in flake.nix
if [[ "$OSTYPE" == "darwin"* ]]; then
  nix run ".#home-manager" -- build -v --flake ".#bryan@memoriam" "$@"
fi
