#!/bin/bash
# build home configs

set -x
cd "$(dirname "$0")" || exit

IFS=" " read -r -a allConfigs <<< "$(nix eval --raw --impure --expr \
  "with builtins; toString (attrNames (getFlake path:$PWD).homeConfigurations)" \
  | xargs
)"

for oneConfig in "${allConfigs[@]}"; do
  nix run home-manager/master -- build --flake ".#$oneConfig" "$@"
done
