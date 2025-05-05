#!/bin/bash
# build default package

set -x
cd "$(dirname "$0")" || exit

nix build --print-build-logs "$@"
# code=$?
#
# exit "$code"
