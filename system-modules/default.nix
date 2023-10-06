{ pkgs, nixosModulesPath, cheznix, ... }:

let
  upstreamModules = (
    cheznix.inputs.system-manager.outPath
    + "/nix/modules/upstream/nixpkgs"
  );
in
{

  disabledModules = [
    ## currently broken so disabled:
    upstreamModules
  ];

  imports = [
    ## non-NixOS modules
    ./zsh.nix
  ] ++
  map (path: nixosModulesPath + path) [
    ## NixOS modules, with a leading "/"
  ];

  config = {
    programs.zsh.enable = true;
    system-manager.allowAnyDistro = true;
    nixpkgs.hostPlatform = pkgs.system;

    # environment.systemPackages = with pkgs; [
    #   zsh
    #   neovim
    #   nix
    # ];  ## wait for better ecosystem support

  };
}
