#!/usr/bin/env -S nix eval --impure --file
# given `$package` attr, find its definition in <nixpkgs>

## `nix eval` does not work with `--arg`
## https://github.com/NixOS/nix/issues/2678

let

  ## so we use environment variables:
  package = builtins.getEnv "package";

  ## load nixpkgs (need to be set up first)
  pkgs = import <nixpkgs> { };
  lib = pkgs.lib;

  ## human readable nixpkgs path,
  ## under e.g. ~/.nix-defexpr/channels
  nixpkgsPath = toString <nixpkgs>;
  storePath = toString pkgs.path;
  ## ^ nixpkgs /nix/store path

  storePosition = pkgs.${package}.meta.position;
  basePosition = lib.removePrefix storePath storePosition;

  nicePosition = toString (/. + nixpkgsPath + basePosition);

in [
  nicePosition
  nixpkgsPath
]
