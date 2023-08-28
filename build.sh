#!/bin/bash
# build home configs

set -x
cd "$(dirname "$0")" || exit

nix build . "$@"

# cd pkgs/tectonic-with-biber || exit
# nix flake lock --update-input nixpkgs_biber
# nix build .#biber
