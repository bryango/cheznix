{ flakeSystem ? args_.system
    or builtins.currentSystem
    or "x86_64-linux"
, ...
} @ args_:

let
  pathString = builtins.toString ./.;
  flake = builtins.getFlake pathString;
  nixpkgs = flake.inputs.nixpkgs;
  lib = flake.lib;
  pkgs = flake.legacyPackages.${flakeSystem};

  /* prepare the arguments for the `nixpkgs` function
  
    Note:
    - "config.*ackageOverrides" will be overriden, not merged
    - "overlays" are composed by stacking them together
    - see e.g. home-manager|nixos: modules/misc/nixpkgs.nix
  */
  overlays =
    (pkgs.overlays or [ ]) ++
    (args_.overlays or [ ]);

  args__ = builtins.removeAttrs args_ [
    "flakeSystem"
    "overlays"
  ];  ## ^ remove processed args

  args = lib.recursiveUpdate
    {
      inherit (pkgs) config;
      inherit overlays;
    }
    args__;

in import nixpkgs args // {
  inherit flake;
}
