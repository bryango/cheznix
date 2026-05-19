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
in

{
  imports = [
    # for nix.registry
    "${nixosModulesPath}/config/nix-flakes.nix"
  ];

  options.system.nixos.flake = {
    nixpkgs = lib.mkOption {
      type = lib.types.nullOr lib.types.attrs;
      default = null;
      example = ''inputs = { nixpkgs = { ... }; }; outputs = { self, nixpkgs, ... }: { ... }; outPath = "...";'';
      description = ''
        The source of the Nixpkgs flake input.
        This is used to construct a flakeref to the nixpkgs source.
      '';
    };
  };

  config = lib.mkIf (cfg.nixpkgs != null) {
    nix.registry.nixpkgs.to =
      let
        narHash = cfg.nixpkgs.narHash or cfg.nixpkgs.sourceInfo.narHash or null;
      in
      {
        type = "github";
        owner = "NixOS";
        repo = "nixpkgs";
        rev = cfg.nixpkgs.rev or cfg.nixpkgs.sourceInfo.rev or "nixpkgs-unstable";
      }
      // lib.optionalAttrs (narHash != null) { inherit narHash; };

    systemd.tmpfiles.rules = lib.mkIf (cfg.nixpkgs != null) (
      let
        storePath = cfg.nixpkgs.outPath or cfg.nixpkgs.sourceInfo.outPath or null;
      in
      lib.optionals (storePath != null) [
        "d ${prefix} 0755 root root -"
        "L+ ${prefix}/nixpkgs - - - - ${storePath}"
      ]
    );

  };
}
