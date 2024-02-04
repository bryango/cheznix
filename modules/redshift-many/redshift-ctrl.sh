#!/bin/bash
# set redshift of all screens

called_as=redshift
executable=redshift

set -x

function purge {
  systemctl --user stop @allInstanceNames@
  "$called_as" -x
  pkill "$executable"
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
