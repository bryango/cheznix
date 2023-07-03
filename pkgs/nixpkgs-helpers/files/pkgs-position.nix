#!/usr/bin/env -S nix eval --impure --file
# given env `$package`, find its definition in <nixpkgs>

## `nix eval` does not work with `--arg`
## https://github.com/NixOS/nix/issues/2678

let

  ## load nixpkgs (need to be set up first)
  pkgs = import <nixpkgs> { };
  lib = pkgs.lib;

  ## get environment variables:
  packageAttrPath = lib.splitString "." (builtins.getEnv "package");
  package = lib.getAttrFromPath packageAttrPath pkgs;

  ## human readable nixpkgs path,
  ## under e.g. ~/.nix-defexpr/channels
  nixpkgsPath = toString <nixpkgs>;
  storePath = toString pkgs.path;
  ## ^ nixpkgs /nix/store path

  storePosition = package.meta.position;
  basePosition = lib.removePrefix storePath storePosition;

  nicePosition = toString (/. + nixpkgsPath + basePosition);

in [
  nicePosition
  nixpkgsPath
]
