/**
  Make flake sources available in the system registry and expose them
  as root user's channels in the legacy channels directory.
*/

{
  options,
  config,
  pkgs,
  lib,
  nixpkgs-follows,
  ...
}:

let

  /**
    recursively collect & flatten flake inputs
    https://github.com/NixOS/nix/issues/3995#issuecomment-1537108310
  */
  collectFlakeInputs =
    name: flake:
    let
      ## avoid infinite recursion from self references
      inputs = removeAttrs (flake.inputs or { }) [ name ];
    in
    lib.concatMapAttrs collectFlakeInputs inputs
    // {
      ${name} = flake; # "high level" inputs win
    };

  prefix = "nix-channels";
  flakeSelfName = "system-config";
  flakeInputs' = collectFlakeInputs flakeSelfName (config.system.nixos.flake or { });

  ## remove the local flakes
  ## to reduce trivial rebuilds
  flakeInputs'' = removeAttrs flakeInputs' [
    nixpkgs-follows
  ];

  flakeInputs = flakeInputs'' // {
    ## include the possibly patched nixpkgs
    inherit (pkgs) nixpkgs-patched;

    ## alias darwin to nix-darwin
    darwin = flakeInputs''.nix-darwin or pkgs.emptyDirectory;
  };

  generateLinks = name: flake: {
    name = "${prefix}/${name}";
    value = {
      source = flake;
    };
  };

  links = lib.mapAttrs generateLinks flakeInputs;

  addActivationScript = lib.mapAttrs (
    name: script: lib.hm.dag.entryAfter [ "installPackages" ] script
  );

in
{

  options.system.nixos = {
    flake = {
      source = lib.mkOption {
        type = lib.types.attrs;
        default = null;
        example = ''inputs = { nixpkgs = { ... }; }; outputs = { self, nixpkgs, ... }: { ... }; outPath = "...";'';
        description = ''
          The source flake used to build the system.
          This attribute set can be obtained from `builtins.getFlake`.
        '';
      };

      nixpkgs = lib.mkOption {
        type = lib.types.nullOr (
          lib.types.oneOf [
            lib.types.str
            lib.types.path
            lib.types.attrs
          ]
        );
        default = null;
        example = "nixpkgs";
        description = ''
          The name or source of the flake input that points to Nixpkgs.
          This is used to construct a flakeref to the nixpkgs source.
        '';
      };
    };
  };

  config = {
    systemd.tmpfiles.rules = [
      ## backward compatible to nix channels
      "L /nix/var/nix/profiles/per-user/root/channels 0644 root root - /etc/${prefix}"
    ];
  };

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
      nix registry add "nix-darwin" "github:LnL7/nix-darwin/${flakeInputs.nix-darwin.sourceInfo.rev}"
    '';
  };

}
