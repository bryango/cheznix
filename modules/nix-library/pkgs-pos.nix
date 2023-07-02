{ system ? builtins.currentSystem or "x86_64-linux"
, package, ... }:

let

  ## load nixpkgs flake
  nixpkgs = builtins.getFlake "nixpkgs";
  pkgs = nixpkgs.legacyPackages.${system};
  lib = pkgs.lib;

  ## human readable nixpkgs path,
  ## under e.g. ~/.nix-defexpr/channels (need to be set up first)
  nixpkgsShortPath = toString <nixpkgs>;
  storePath = toString pkgs.path;

  storePosition = pkgs.${package}.meta.position;
  basePosition = lib.removePrefix storePath storePosition;

  nicePosition = toString (/. + nixpkgsShortPath + basePosition);

in [
  nicePosition
  nixpkgsShortPath
]
