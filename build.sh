#!/bin/bash
# build home configs

set -x
cd "$(dirname "$0")" || exit

# same command for `home-manager` and `darwin-rebuild`
# see: packages.${system}.default
exec nix run . -- build -v "$@"
