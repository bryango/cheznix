#!/usr/bin/env -S nix repl --impure --file
# get a flake, and its `pkgs` and `lib`

{ system ? builtins.currentSystem or "x86_64-linux"
, flakeref ? "nixpkgs"
, ... }:

let
  flake = builtins.getFlake flakeref;
  pkgs = flake.legacyPackages.${system} or {};
  lib = flake.lib or pkgs.lib or {};
in flake // { inherit flake pkgs lib; }
