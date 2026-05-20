{
  config,
  lib,
  nixosModulesPath,
  ...
}:

let

  # backward compatible to nix channels
  prefix = "/nix/var/nix/profiles/per-user/root/channels";
  cfg = config.system.nixos.flake;

  nixpkgs = cfg.nixpkgs;
  narHash = nixpkgs.narHash or nixpkgs.sourceInfo.narHash or null;
  rev = nixpkgs.rev or nixpkgs.sourceInfo.rev or null;
  storePath = nixpkgs.outPath or nixpkgs.sourceInfo.outPath or null;

in

{
  imports = [
    # for nix.registry
    "${nixosModulesPath}/config/nix-flakes.nix"
  ];

  options.system.nixos.flake = {
    source = lib.mkOption {
      type = lib.types.nullOr lib.types.attrs;
      default = null;
      example = ''
        {
          inputs = { nixpkgs = { ... }; };
          outputs = { self, nixpkgs, ... }: { ... };
          outPath = "...";
          narHash = "...";
          rev = "...";
        }
      '';
      description = ''
        The source flake used to build the system, as an attribute set.
        This attribute set can be obtained from `builtins.getFlake`.
      '';
    };

    nixpkgs = lib.mkOption {
      type = lib.types.nullOr lib.types.attrs;
      default = cfg.source.inputs.nixpkgs or null;
      example = ''
        {
          outputs = { ... }: { ... };
          outPath = "...";
          narHash = "...";
          rev = "...";
        }
      '';
      description = ''
        The Nixpkgs flake input as an attribute set.
        The structure of this attribute set should be consistent with
        the output of `builtins.getFlake`.
      '';
    };
  };

  config = lib.mkIf (nixpkgs != null) {
    nix.registry.nixpkgs.to = {
      type = "github";
      owner = "NixOS";
      repo = "nixpkgs";
    }
    // lib.optionalAttrs (narHash != null) { inherit narHash; }
    // lib.optionalAttrs (rev != null) { inherit rev; }
    // lib.optionalAttrs (rev == null) { ref = "nixpkgs-unstable"; };

    systemd.tmpfiles.rules = lib.mkIf (nixpkgs != null) (
      lib.optionals (storePath != null) [
        "d ${prefix} 0755 root root -"
        "L+ ${prefix}/nixpkgs - - - - ${storePath}"
      ]
    );

  };
}
