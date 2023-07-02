{ config, pkgs, lib, nixpkgs-follows, ... }:

let

  module = "nixpkgs-helpers";
  category = "programs";

  opts = {
    enable = lib.mkEnableOption module;

    flakeref = with lib; mkOption {
      type = types.str;
      default = nixpkgs-follows;
      description = ''
        Set the default flake ref to get via `builtins.getFlake`.
      '';
    };

    viewer = with lib; mkOption {
      type = types.str;
      default = "echo";
      example = "code --goto";
      description = ''
        Set the editor command to show the package definition.
      '';
    };

  };

  cfg = config.${category}.${module};

  ## from github:bryango/nixpkgs-config
  helpers = pkgs.nixpkgs-helpers;

  nix-open = pkgs.binarySubstitute "nix-open" {
    src = ./nix-open;
    inherit (cfg) flakeref;
    inherit (helpers) pkgs-lib;
  };

  nix-pos = pkgs.binarySubstitute "nix-pos" {
    src = ./nix-pos;
    inherit (cfg) viewer;
    inherit (helpers) pkgs-position;
  };



in {

  options.${category}.${module} = opts;

  config = lib.mkIf cfg.enable {
    home.packages = [
      helpers
      nix-open
      nix-pos
    ];
  };

}
