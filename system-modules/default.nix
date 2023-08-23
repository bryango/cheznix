{ pkgs, ... }:

{
  config = {
    environment.systemPackages = with pkgs; [
      zsh
      neovim
      nix
    ];
  };
}
