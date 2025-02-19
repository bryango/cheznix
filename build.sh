#!/bin/bash
# build home configs

set -x
cd "$(dirname "$0")" || exit

IFS=" " read -r -a allConfigs <<< "$(nix eval --raw --impure --expr \
  "with builtins; attrNames (getFlake path:$PWD).homeConfigurations" \
  --apply toString \
  | xargs  ## space separated lists
)"

for oneConfig in "${allConfigs[@]}"; do
  nix run . -- build -v --flake ".#$oneConfig" "$@"
done

IFS=" " read -r -a allConfigs <<< "$(nix eval --raw --impure --expr \
  "with builtins; attrNames (getFlake path:$PWD).darwinConfigurations" \
  --apply toString \
  | xargs  ## space separated lists
)"

for oneConfig in "${allConfigs[@]}"; do
  # Build darwin flake using:
  # $ darwin-rebuild build --flake .#simple
  nix run ".#darwin-rebuild" -- build -v --flake ".#$oneConfig" "$@"
done
