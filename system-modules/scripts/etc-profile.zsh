#!/usr/bin/env zsh
#
# For zprofile: all POSIX shells should source /etc/profile upon login.
# However, zsh does not implement this by default, so we do it ourselves.
#
# This behavior follows from Arch's default:
#
# - https://gitlab.archlinux.org/archlinux/packaging/packages/zsh/-/blob/main/zprofile
# - https://wiki.archlinux.org/title/Zsh
#
# So here we only apply this Arch-based distros for the moment.

if [[ -f /etc/os-release ]]; then
  source /etc/os-release
  if [[ "$ID" == "arch" ]] || [[ "$ID_LIKE" == *arch* ]]; then
    emulate sh -c 'source /etc/profile'
  fi
fi
