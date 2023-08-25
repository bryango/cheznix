{ pkgs, ... }:

{
  config = {
    system-manager.allowAnyDistro = true;
    nixpkgs.hostPlatform = pkgs.system;

    # environment.systemPackages = with pkgs; [
    #   zsh
    #   neovim
    #   nixVersions.nix_2_17
    # ];  ## wait for better ecosystem support

  };
}
