{ system ? builtins.currentSystem or "x86_64-linux"
, flakeref ? "@flakeref@"
, ... }:

let
  flake = builtins.getFlake flakeref;
  pkgs = flake.legacyPackages.${system} or {};
  lib = flake.lib or pkgs.lib or {};
in flake // { inherit pkgs lib; }
