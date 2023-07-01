{ pkgs, lib, cheznix, ... }:

let

  flakeInputs = pkgs.collectFlakeInputs "cheznix" cheznix;

  generateLinks = prefix: name: flake: {
    name = "${prefix}/${name}";
    value = { source = flake.outPath; };
  };

  links = lib.mapAttrs'
    (generateLinks ".nix-defexpr/channels")
    flakeInputs;

in {

  ## backward compatible to nix channels
  ## prevents cheznix inputs from being garbage collected
  config.home.file = links;
}
