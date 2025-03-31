{ pkgs, lib, cheznix, attrs, config, ... }:

{
  # List packages installed in system profile. To search by name, run:
  # $ nix-env -qaP | grep wget
  users.users.${attrs.username} = {
    packages = with pkgs; [
      iterm2
      code-cursor
    ];
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
      "wechat"
      "nutstore"
      "karabiner-elements"
      "middleclick"
      "rectangle"
      "tunnelblick"
      "hiddenbar"
    ];
  };

  services.tailscale.enable = true;

  nix.settings = {
    experimental-features = "nix-command flakes fetch-closure";
    trusted-users = lib.optionals pkgs.hostPlatform.isDarwin [ "@admin" ];
    # extra-nix-path = "nixpkgs=flake:nixpkgs";
  };

  nix.channel.enable = false;

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
