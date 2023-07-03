{ options, pkgs, lib, cheznix, nixpkgs-follows, ... }:

let

  ## backward compatible to nix channels
  prefix = ".nix-defexpr/channels";

  flakeSelfName = "cheznix-itself";  ## just a tracker, could be anything
  flakeInputs' = pkgs.collectFlakeInputs flakeSelfName cheznix;

  ## remove the cheznix flake itself
  ## to reduce trivial rebuilds
  flakeInputs = builtins.removeAttrs flakeInputs' [ flakeSelfName ];

  generateLinks = prefix: name: flake: {
    name = "${prefix}/${name}";
    value = { source = flake.outPath; };
  };

  links = lib.mapAttrs' (generateLinks prefix) flakeInputs;
  nixpkgs-flake = cheznix.inputs.${nixpkgs-follows};

in {

  config = {

    ## prevent cheznix inputs from being garbage collected
    home.file = links;

    ## add `nixpkgs-follows` to flake registry at "runtime"
    home.activation.userFlakeRegistry
      = lib.hm.dag.entryAfter [ "installPackages" ] ''
        nix registry add ${nixpkgs-follows} ${nixpkgs-flake}
      '';
  };

  config.programs = lib.mkIf (options.programs ? nixpkgs-helpers) {

    ## use `nixpkgs-follows` as a flakeref
    nixpkgs-helpers = {
      enable = true;
      flakeref = nixpkgs-follows;
    };

  };

}
