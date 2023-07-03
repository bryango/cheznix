{ config, pkgs, lib, nixpkgs-follows, ... }:

let

  program = "nixpkgs-helpers";
  module = program;
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

    directory = with lib; mkOption {
      type = types.str;
      default = ".nix-defexpr/${program}";
      description = ''
        Set the directory to link to `${program}`.
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
  helpers = pkgs.${program}.files;

  ## generate the links one by one
  generateLinks = helper: path: {
    source = helpers.${helper};
    target = "${cfg.directory}/${helper}.nix";
  };
  ## ... such that they can be referenced later
  links = lib.mapAttrs generateLinks helpers;
  targets = lib.mapAttrs (helper: link: link.target) links;

  nix-open = pkgs.binarySubstitute "nix-open" {
    src = ./nix-open;
    inherit (cfg) flakeref;
    pkgslib = "$HOME/${targets.pkgs-lib}";  ## `foo-bar` not valid
  };

  nix-pos = pkgs.binarySubstitute "nix-pos" {
    src = ./nix-pos;
    inherit (cfg) viewer;
    pkgsposition = "$HOME/${targets.pkgs-position}";
  };

  scripts = pkgs.symlinkJoin {
    name = "${module}-module";
    paths = [
      nix-open
      nix-pos
    ];
  };

in {

  options.${category}.${module} = opts;

  config = lib.mkIf cfg.enable {

    home.file = links;
    home.packages = [
      scripts
    ];
  };

}
