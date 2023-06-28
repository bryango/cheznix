#!/bin/bash
# set brightness of external monitor

[[ -z $XRANDR_OUTPUT ]] && XRANDR_OUTPUT=@output@

redshift-ctrl purge

xrandr --output "$XRANDR_OUTPUT" --brightness "$@"

redshift-ctrl init
