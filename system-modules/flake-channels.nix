{
  config,
  lib,
  ...
}:

let
  cfg = config.system.nixos.flake;
in

{
  options.system.nixos = {
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

  config.nix.registry = lib.mkIf (cfg.nixpkgs != null) {
    nixpkgs.to = {
      type = "github";
      owner = "NixOS";
      repo = "nixpkgs";
      rev = cfg.nixpkgs.rev or cfg.nixpkgs.sourceInfo.rev or "nixpkgs-unstable";
      narHash = cfg.nixpkgs.narHash or cfg.nixpkgs.sourceInfo.narHash or null;
    };
  };
}
