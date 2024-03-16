{ options, pkgs, lib, cheznix, nixpkgs-follows, ... }:

let

  ## backward compatible to nix channels
  prefix = ".nix-defexpr/channels";

  flakeSelfName = "cheznix";
  flakeInputs' = lib.collectFlakeInputs flakeSelfName cheznix;

  ## remove the local flakes
  ## to reduce trivial rebuilds
  flakeInputs'' = removeAttrs flakeInputs' [
    flakeSelfName
    nixpkgs-follows
  ];

  flakeInputs = flakeInputs'' // {
    ## include the patched nixpkgs
    inherit (pkgs) nixpkgs-patched;

    ## include the home-manager flake itself from nixpkgs
    home-manager.outPath = pkgs.home-manager.src;
  };

  generateLinks = prefix: name: flake: {
      source = flake.outPath;
      target = "${prefix}/${name}";
  };

  links = lib.mapAttrs (generateLinks prefix) flakeInputs;

in {

  config = {

    ## prevent cheznix inputs from being garbage collected
    home.file = links;

    ## add `nixpkgs-follows` to flake registry at "runtime"
    home.activation.userFlakeRegistry
      = lib.hm.dag.entryAfter [ "installPackages" ] ''

          flake=''${FLAKE_CONFIG_URI%#*}  ## scheme: "path:$HOME/..."
          nixpkgs="$flake/${nixpkgs-follows}"
          ## ^ relies on the subdir structure of the input!

          nix registry add "${nixpkgs-follows}" "$nixpkgs"
          nix registry add "${flakeSelfName}" "$flake"
          nix registry add "home-manager" "path:$HOME/${links.home-manager.target}"

          ## crazy hack to get the patched nixpkgs flake
          if nixpkgs_patched=$(
            nix run nixpkgs\#nixVersions.nix_2_21 -- eval --impure --raw --expr \
              "(builtins.fetchTree \"path:$HOME/${links.nixpkgs-patched.target}\").outPath"
          ); then
            nix registry add "nixpkgs-patched" "$nixpkgs_patched"
          fi
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
