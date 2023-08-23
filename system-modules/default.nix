{ pkgs, ... }:

{
  config = {
    system-manager.allowAnyDistro = true;
    nixpkgs.hostPlatform = pkgs.system;
    environment.systemPackages = with pkgs; [
      ## wait for better ecosystem support
      # zsh
      # neovim
      nix
    ];
  };
}
