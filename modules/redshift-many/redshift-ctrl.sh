#!/bin/bash
# set redshift of all screens

process_name=redshift
executable=redshift

set -x

function purge {
  systemctl --user stop @allInstanceNames@
  "$executable" -x
  pkill --exact "$process_name"
}

function init {
  systemctl --user start @allInstanceNames@
}

# init
case "$1" in
  purge)
    purge
    ;;
  init)
    init
    ;;
  *)
    purge
    init
    ;;
esac
