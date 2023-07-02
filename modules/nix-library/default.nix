{ config, pkgs, lib, nixpkgs-follows, ... }:

let

  module = "nix-library";
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

    pkgslib = with lib; mkOption {
      type = types.str;
      default = ".nix-defexpr/pkgs-lib";
      description = ''
        Set the directory for `pkgs-lib.nix`,
        which provides the default `pkgs` and `lib`.
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

  filenames = [
    "default"
    "pkgs-position"
  ];

  generateLinks = filename: {
    source = ./pkgs-lib + "/${filename}.nix";
    target = "${cfg.pkgslib}/${filename}.nix";
  };

  links = lib.genAttrs filenames generateLinks;

  nix-open = pkgs.binarySubstitute "nix-open" {
    src = ./nix-open;
    inherit (cfg) pkgslib flakeref;
  };

  nix-pos = pkgs.binarySubstitute "nix-pos" {
    src = ./nix-pos;
    inherit (cfg) viewer;
    pkgs-position = links.pkgs-position.target;
  };



in {

  options.${category}.${module} = opts;

  config = lib.mkIf cfg.enable {
    home.file = links;

    home.packages = [
      nix-open
      nix-pos
    ];
  };

}
