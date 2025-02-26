{ pkgs, lib, cheznix, attrs, ... }:

{
  # List packages installed in system profile. To search by name, run:
  # $ nix-env -qaP | grep wget
  environment.systemPackages = with pkgs; [
    iterm2
  ];

  system.activationScripts = {
    extraActivation.text = ''
      >&2 echo linking /etc/nix-darwin...
      set -xeuo pipefail
      ln -sf "${attrs.homeDirectory or "/Users/${attrs.username}"}/.config/home-manager" /etc/nix-darwin
      set +x
    '';
  };

  fonts.packages = [
    pkgs.nerd-fonts.hack
  ];

  /** homebrew managed incrementally; need to install first */
  homebrew = {
    enable = true;
    casks = [
      "firefox"
      "tencent-meeting"
    ];
  };
  services.tailscale.enable = true;

  nix.settings = {
    experimental-features = "nix-command flakes fetch-closure";
    trusted-users = lib.optionals pkgs.hostPlatform.isDarwin [ "@admin" ];
    # extra-nix-path = "nixpkgs=flake:nixpkgs";
  };

  # Set Git commit hash for darwin-version.
  system.configurationRevision =
    cheznix.rev
      or cheznix.dirtyRev
      or cheznix.lastModifiedDate
      or cheznix.lastModified
      or null;

  # Used for backwards compatibility, please read the changelog before changing.
  # $ darwin-rebuild changelog
  system.stateVersion = 6;

  # The platform the configuration will be used on.
  # nixpkgs.hostPlatform = "aarch64-darwin";
}
