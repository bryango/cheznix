{ lib, linkFarm }:

let

  helpers = {
    pkgs-lib = ./pkgs-lib.nix;
    pkgs-position = ./pkgs-position.nix;
  };

  generateLinks = attr: value: {
    name = builtins.baseNameOf value;
    value = value;
  };

  links = lib.mapAttrs' generateLinks helpers;

in (linkFarm "nixpkgs-helpers" links).overrideAttrs (
  prev: {
    ## make helpers accessible via attributes
    passthru = prev.passthru // helpers;
  }
)
