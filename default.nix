{ system ? builtins.currentSystem or "x86_64-linux", ... }:

let
  pathString = builtins.toString ./.;
  flake = builtins.getFlake pathString;
in flake // flake.legacyPackages.${system}
