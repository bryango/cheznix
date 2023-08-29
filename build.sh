#!/bin/bash
# build home configs

set -x
cd "$(dirname "$0")" || exit

nix build . "$@"

set +x
echo "## check consistency of biber217"

set -x
src=$(nix eval --raw --no-write-lock-file ./pkgs/tectonic-with-biber#biber)
out=$(nix eval --raw .#biber217)

set +x
if [[ "$src" == "$out" ]]
then echo "## consistent!"
else echo "## inconsistent!"
fi
