{ pkgs, lib, cheznix, attrs, config, ... }:

let

  homebrewEnv = {
    HOMEBREW_AUTO_UPDATE_SECS = "86400";
    HOMEBREW_API_AUTO_UPDATE_SECS = "86400";
    HOMEBREW_API_DOMAIN = "https://mirrors.tuna.tsinghua.edu.cn/homebrew-bottles/api";
    HOMEBREW_BOTTLE_DOMAIN = "https://mirrors.tuna.tsinghua.edu.cn/homebrew-bottles";
  };

in

{
  system.primaryUser = attrs.username;

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
    histSize = 1000000;
  };

  environment.variables = homebrewEnv // {

  };

  /** homebrew managed incrementally; need to install first */
  homebrew = {
    enable = true;
    onActivation = {
      cleanup = "check"; # currently failing due to brew trust & not passing `extraEnv` below
      extraFlags = [ "--verbose" ];
      extraEnv = homebrewEnv // {
        # note: should not set this in environment.variables as it's user dependent
        XDG_CONFIG_HOME = "/Users/${config.homebrew.user}/.config";
      };
    };
    taps = [
      "bryango/ccswitch"
      "jundot/omlx"
      "nohajc/anylinuxfs"
    ];
    brews = [
      "cocoapods"
      "unbound"
      # "qwen-code"
      # "openclaw-cli"

      # must use full name for custom taps
      "jundot/omlx/omlx"
      "nohajc/anylinuxfs/anylinuxfs"
    ];
    casks = [
      # trusted
      "firefox"
      "virtualbox"
      "vlc"
      "darktable"

      # proprietary but necessary
      "google-chrome"
      "typeless"
      "nutstore"
      "zoom"
      "visual-studio-code"
      "tailscale-app"
      "obsidian"
      "yuanbao"
      "notion"
      "betterdisplay"
      "lm-studio"
      "clash-verge-rev"
      "chatgpt"
      "chatgpt-classic"
      "daisydisk"
      "claude-code"
      "spotify"
      "typora"
      "whatsapp"

      # probably okay
      "iterm2"
      "jellyfin"
      "karabiner-elements"
      "tunnelblick" # openvpn client
      "racket"
      "rustdesk"
      "bryango/ccswitch/cc-switch"
    ];
  };

  services.tailscale.enable = true; # use along with the cask app

  nix.settings = {
    experimental-features = "nix-command flakes fetch-closure";
    trusted-users = lib.optionals pkgs.stdenv.hostPlatform.isDarwin [ "@admin" ];
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
      # AppleShowAllFiles = true;
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

      >&2 echo export brew info...
      cat "${brewfilePackage}" > "${brewFile}"

      # shellcheck disable=SC2024
      sudo \
        --user=${lib.escapeShellArg config.homebrew.user} \
        --set-home \
        /opt/homebrew/bin/brew info --installed --json=v2 > "${brewInfo}"

      set +x
    '';
  };

  # Used for backwards compatibility, please read the changelog before changing.
  # $ darwin-rebuild changelog
  system.stateVersion = 6;
}
