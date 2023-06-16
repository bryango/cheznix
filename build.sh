#!/bin/bash
# build home configs

set -x
cd "$(dirname "$0")" || exit

nix eval --impure --expr \
  "with builtins; attrNames (getFlake path:$PWD).legacyPackages.x86_64-linux.config" \
  | xargs
