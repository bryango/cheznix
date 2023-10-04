{ pkgs, nixosModulesPath, ... }:

{
  imports = [
    ## non-NixOS modules
    ./zsh.nix
  ] ++
  map (path: nixosModulesPath + path) [
    ## NixOS modules, with a leading "/"
  ];

  config = {
    system-manager.allowAnyDistro = true;
    nixpkgs.hostPlatform = pkgs.system;

    # environment.systemPackages = with pkgs; [
    #   zsh
    #   neovim
    #   nix
    # ];  ## wait for better ecosystem support

  };
}
