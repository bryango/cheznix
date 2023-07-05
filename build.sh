#!/bin/bash
# build home configs

set -x
cd "$(dirname "$0")" || exit

nix build .#user-overlaid
