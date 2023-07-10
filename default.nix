{ system ? builtins.currentSystem or "x86_64-linux", ... } @ args_:

let
  pathString = builtins.toString ./.;
  flake = builtins.getFlake pathString;
  nixpkgs = flake.inputs.nixpkgs;
  lib = flake.lib;
  pkgs = flake.legacyPackages.${system};

  /* prepare the arguments for the `nixpkgs` function
  
    Caveats:
    - the "*ackageOverrides" will be overriden, not merged
    - only legacy "system" is supported, not "localSystem"
  */
  args = lib.recursiveUpdate {
    inherit (pkgs)
      config
      overlays
    ;
  } args_;

in import nixpkgs args // {
  inherit flake;
}
