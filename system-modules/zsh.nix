## a fork of nixpkgs:nixos/modules/programs/zsh/zsh.nix

{ pkgs, lib, config, ... }:

let
  inherit (lib)
    mkOption
    mkIf
    types
    optional
    ;

  cfg = config.programs.zsh;
in
{

  imports = [
    ./shells-env.nix
  ];

  options = {
    programs.zsh = {

      enable = mkOption {
        default = false;
        description = lib.mdDoc ''
          Whether to configure zsh as an interactive shell.
        '';
        type = types.bool;
      };

      enableCompletion = mkOption {
        default = true;
        description = lib.mdDoc ''
          Enable zsh completion for all interactive zsh shells.
        '';
        type = types.bool;
      };
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [ pkgs.zsh ]
      ++ optional cfg.enableCompletion pkgs.nix-zsh-completions;

    environment.pathsToLink = optional cfg.enableCompletion "/share/zsh";

    environment.shells =
      [
        "/run/system-manager/sw/bin/zsh"
        # "${pkgs.zsh}/bin/zsh"
      ];
  };
}
