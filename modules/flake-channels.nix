{ options, config, pkgs, lib, cheznix, nixpkgs-follows, ... }:

let

  inherit (config.home) homeDirectory;

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

  addActivationScript = lib.mapAttrs (name: script:
    lib.hm.dag.entryAfter [ "installPackages" ] script
  );

in {

  config.home.activation = addActivationScript {

    ## add `nixpkgs-follows` to flake registry at "runtime"
    userFlakeRegistry = ''
      flake=''${FLAKE_CONFIG_URI%#*}  ## scheme: "path:$HOME/..."
      nixpkgs="$flake/${nixpkgs-follows}"
      # ^ relies on the subdir structure of the input!

      if [[ $flake == path:* ]] || [[ $flake == /* ]]; then
        nix registry add "${nixpkgs-follows}" "$nixpkgs"
        nix registry add "${flakeSelfName}" "$flake"
      else
        # guard against illegal flake refs
        >&2 echo "nix registry: illegal home-manager \$FLAKE_CONFIG_URI: $flake"
      fi
      nix registry add "home-manager" "${links.home-manager.source}"

      nix registry add "nixpkgs" "github:NixOS/nixpkgs/${flakeInputs.nixpkgs.sourceInfo.rev}"
    '';

    ## prevent cheznix inputs from being garbage collected
    userFlakeChannels = lib.concatStrings (
      lib.mapAttrsToList
        (name: link: ''
          ln -sfT "${link.source}" "${homeDirectory}/${link.target}"
        '')
        links
    );
  };

  config.programs = lib.mkIf (options.programs ? nixpkgs-helpers) {

    ## use `nixpkgs-follows` as a flakeref
    nixpkgs-helpers = {
      enable = true;
      flakeref = nixpkgs-follows;
    };

  };

}
