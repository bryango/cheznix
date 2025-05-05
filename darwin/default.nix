{ pkgs, lib, cheznix, attrs, config, ... }:

{
  # List packages installed in system profile. To search by name, run:
  # $ nix-env -qaP | grep wget
  users.users.${attrs.username} = {
    packages = [
      # pkgs.code-cursor
    ];
  };

  fonts.packages = [
    pkgs.nerd-fonts.hack
    pkgs.ankacoder-condensed
  ];

  programs.zsh = {
    enableGlobalCompInit = false; # defer for later
  };

  /** homebrew managed incrementally; need to install first */
  homebrew = {
    enable = true;
    brews = [
      "cocoapods"
    ];
    casks = [
      # trusted
      "firefox"

      # proprietary but necessary
      "nutstore"
      "zoom"
      "visual-studio-code"

      # probably okay
      "iterm2"
      "karabiner-elements"
      "tunnelblick" # openvpn client
    ];
  };

  services.tailscale.enable = true;

  nix.settings = {
    experimental-features = "nix-command flakes fetch-closure";
    trusted-users = lib.optionals pkgs.hostPlatform.isDarwin [ "@admin" ];
    extra-nix-path = "nixpkgs=flake:nixpkgs";
  };

  nixpkgs.flake = {
    setFlakeRegistry = false; # managed by home-manager
    setNixPath = false; # managed manually in nix.settings.extra-nix-path
  };

  nix.channel.enable = false;

  security.pam.services.sudo_local.touchIdAuth = true;

  system.defaults = {
    NSGlobalDomain = {
      AppleShowAllExtensions = true;
      AppleShowAllFiles = true;
    };
    finder = {
      FXPreferredViewStyle = "Nlsv";
    };
    CustomUserPreferences = {
      NSGlobalDomain = {
        # adjust status whitespace
        NSStatusItemSpacing = 12;
        NSStatusItemSelectionPadding = 8;
      };
    };
  };

  # Set Git commit hash for darwin-version.
  system.configurationRevision =
    cheznix.rev
      or cheznix.dirtyRev
      or cheznix.lastModifiedDate
      or cheznix.lastModified
      or null;

  system.activationScripts = let
    etcNixDarwin = "/etc/nix-darwin";
    brewfilePackage = pkgs.writeText "Brewfile" config.homebrew.brewfile;
    brewFile = "${etcNixDarwin}/Brewfile";
    brewInfo = "${etcNixDarwin}/brew-info.json";
  in {
    # see: https://github.com/nix-darwin/nix-darwin/blob/master/modules/system/activation-scripts.nix
    extraActivation.text = ''
      set -xeuo pipefail

      >&2 echo linking /etc/nix-darwin...
      ln -sfn "${attrs.homeDirectory or "/Users/${attrs.username}"}/.config/home-manager" "${etcNixDarwin}"

      set +x
    '';
    postUserActivation.text = ''
      set -xeuo pipefail

      >&2 echo export brew info...
      cat "${brewfilePackage}" > "${brewFile}";
      /opt/homebrew/bin/brew info --installed --json=v2 > "${brewInfo}";

      set +x
    '';
  };

  # Used for backwards compatibility, please read the changelog before changing.
  # $ darwin-rebuild changelog
  system.stateVersion = 6;

  # The platform the configuration will be used on.
  # nixpkgs.hostPlatform = "aarch64-darwin";
}
