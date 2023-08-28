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
  nix run . -- build --flake ".#$oneConfig" "$@"
done
