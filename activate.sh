#!/bin/bash
# home-manager activation script

set -x
cd "$HOME" || exit

chezmoi init --ssh bryango/chezmoi
