{ options, pkgs, lib, cheznix, nixpkgs-follows, ... }:

let

  ## backward compatible to nix channels
  prefix = ".nix-defexpr/channels";

  flakeSelfName = "cheznix";
  flakeInputs' = pkgs.lib.collectFlakeInputs flakeSelfName cheznix;

  ## remove the local flakes
  ## to reduce trivial rebuilds
  flakeInputs'' = removeAttrs flakeInputs' [
    flakeSelfName
    nixpkgs-follows
  ];

  flakeInputs = flakeInputs'' // {
    ## include the patched nixpkgs
    inherit (pkgs) nixpkgs-patched;

    ## alias darwin to nix-darwin
    darwin = flakeInputs''.nix-darwin;
  };

  sourceInfo = flake: flake.sourceInfo or { };
  revOf = flake: flake.rev or (sourceInfo flake).rev or null;
  narHashOf = flake: flake.narHash or (sourceInfo flake).narHash or null;
  outPathOf = flake: flake.outPath or (sourceInfo flake).outPath or null;

  mkChannel = name: flake: {
    name = "${prefix}/${name}";
    value.source = outPathOf flake;
  };

  channels = lib.mapAttrs' mkChannel flakeInputs;

  query = attrs:
    lib.optionalString (attrs != { }) (
      "?" + lib.concatStringsSep "&" (
        lib.mapAttrsToList
          (name: value: "${name}=${lib.strings.escapeURL value}")
          attrs
      )
    );

  githubRef = { owner, repo, flake }:
    let
      rev = revOf flake;
      narHash = narHashOf flake;
    in
    assert rev != null;
    "github:${owner}/${repo}/${rev}"
    + query (lib.optionalAttrs (narHash != null) { inherit narHash; });

  registryRefs = {
    nixpkgs = githubRef {
      owner = "NixOS";
      repo = "nixpkgs";
      flake = flakeInputs.nixpkgs;
    };
    home-manager = githubRef {
      owner = "nix-community";
      repo = "home-manager";
      flake = flakeInputs.home-manager;
    };
    nix-darwin = githubRef {
      owner = "nix-darwin";
      repo = "nix-darwin";
      flake = flakeInputs.nix-darwin;
    };
  };

in {

  config = lib.mkMerge [
    {
      home.file = channels;

      home.activation.userFlakeRegistry = lib.hm.dag.entryAfter [ "installPackages" ] ''
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

        nix registry add "nixpkgs" "${registryRefs.nixpkgs}"
        nix registry add "home-manager" "${registryRefs.home-manager}"
        nix registry add "nix-darwin" "${registryRefs.nix-darwin}"
      '';
    }

    (lib.mkIf (options.programs ? nixpkgs-helpers) {

      programs.nixpkgs-helpers = {
        ## use `nixpkgs-follows` as a flakeref
        enable = true;
        flakeref = nixpkgs-follows;
      };

    })
  ];

}
