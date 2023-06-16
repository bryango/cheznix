#!/bin/bash
# build home configs

set -x
cd "$(dirname "$0")" || exit

nix eval --raw --impure --expr \
  "with builtins; toString (attrNames (getFlake path:$PWD).config)" \
  | xargs
