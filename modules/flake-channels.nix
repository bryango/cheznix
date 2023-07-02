{ pkgs, lib, cheznix, nixpkgs-follows, ... }:

let

  ## backward compatible to nix channels
  prefix = ".nix-defexpr/channels";
  flakeInputs = pkgs.collectFlakeInputs "cheznix" cheznix;

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

    ## use `nixpkgs-follows` as a flakeref
    programs.nix-library = {
      enable = true;
      flakeref = nixpkgs-follows;
    };
  };

}
