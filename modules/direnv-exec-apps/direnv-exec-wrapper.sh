#!/bin/bash
# wrap executable names with direnv

cmd=$(basename "$0")

# remove this script from PATH
this_path=$(dirname "$0")
PATH=":$PATH:"
PATH="${PATH//:$this_path:/:}"
PATH="${PATH#:}"
PATH="${PATH%:}"

exec -a "$cmd" direnv exec . "$cmd" "$@"
