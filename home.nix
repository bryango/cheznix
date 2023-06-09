{ pkgs, attrs, ... }:

let

  ## python2 marked insecure: https://github.com/NixOS/nixpkgs/pull/201859
  ## ... last hydra build before that:
  ##     https://hydra.nixos.org/eval/1788908?filter=python2&full=#tabs-inputs
  ## ... obtained by inspecting:
  ##     https://hydra.nixos.org/jobset/nixpkgs/trunk/evals
  nixpkgs_python2 = import (builtins.fetchTarball {
    url = "https://github.com/NixOS/nixpkgs/archive/764b725c359eb82f2f840ee915365874fdf109fb.tar.gz";
    sha256 = "1yazcc1hng3pbvml1s7i2igf3a90q8v8g6fygaw70vis32xibhz9";
    ## ... generated from `nix-prefetch-url --unpack`
  }) {
    inherit (attrs) system config;
    ## https://github.com/nix-community/home-manager/issues/616#issuecomment-568612737
  };

in {
  # The home.packages option allows you to install Nix packages into your
  # environment.
  home.packages = with pkgs; [

    ## nix utils
    # nix  # manage itself
    nvd
    nix-tree
    nixpkgs-fmt  # the official (?) formatter
    nil
    cachix
    hydra-check

    # apps
    circumflex  # Hacker News terminal
    uxplay  # airplay server
    # getoptions  # shell argument parser

    # python2 apps from `nixpkgs_python2`
    gimp-with-plugins

    # # It is sometimes useful to fine-tune packages, for example, by applying
    # # overrides. You can do that directly here, just don't forget the
    # # parentheses. Maybe you want to install Nerd Fonts with a limited number of
    # # fonts?
    # (pkgs.nerdfonts.override { fonts = [ "FantasqueSansMono" ]; })

    # # You can also create simple shell scripts directly inside your
    # # configuration. For example, this adds a command 'my-hello' to your
    # # environment:
    # (pkgs.writeShellScriptBin "my-hello" ''
    #   echo "Hello, ${config.home.username}!"
    # '')
  ];

  # Home Manager needs a bit of information about you and the paths it should
  # manage. ### WARNING: requires `attrs` from `bryango/attrs`
  home.username = attrs.username;
  home.homeDirectory = attrs.homeDirectory;

  # This value determines the Home Manager release that your configuration is
  # compatible with. This helps avoid breakage when a new Home Manager release
  # introduces backwards incompatible changes.
  #
  # You should not change this value, even if you update Home Manager. If you do
  # want to update the value, then make sure to first check the Home Manager
  # release notes.
  home.stateVersion = "22.11"; # Please read the comment before changing.

  ## migrated from ~/.config/nixpkgs/config.nix
  nixpkgs.config = {
    packageOverrides = pkgs: with pkgs; {

      ## specify user mods
      gimp-with-plugins = with nixpkgs_python2; gimp-with-plugins.override {
        plugins = with gimpPlugins; [ resynthesizer ];
      };
      gimp = with nixpkgs_python2; gimp.override {
        withPython = true;
      };
    };

    permittedInsecurePackages = [
      "python-2.7.18.6"
      "python-2.7.18.6-env"
    ];
  };

  nixpkgs.overlays = [
    (self: super: {
      ## package overlays
    })
  ];

  # Home Manager is pretty good at managing dotfiles. The primary way to manage
  # plain files is through 'home.file'.
  home.file = {
    # # Building this configuration will create a copy of 'dotfiles/screenrc' in
    # # the Nix store. Activating the configuration will then make '~/.screenrc' a
    # # symlink to the Nix store copy.
    # ".screenrc".source = dotfiles/screenrc;

    # # You can also set the file content immediately.
    # ".gradle/gradle.properties".text = ''
    #   org.gradle.console=verbose
    #   org.gradle.daemon.idletimeout=3600000
    # '';
  };

  # You can also manage environment variables but you will have to manually
  # source
  #
  #  ~/.nix-profile/etc/profile.d/hm-session-vars.sh
  #
  # or
  #
  #  /etc/profiles/per-user/bryan/etc/profile.d/hm-session-vars.sh
  #
  # if you don't want to manage your shell through Home Manager.
  home.sessionVariables = {
    # EDITOR = "emacs";
  };

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;

  ## use system manpage
  programs.man.enable = false;

  ## modules override
  imports = [
    ./redshift-many
  ];

  ## redshift
  services.redshift-many = {
    redshift = {
      settings.randr.crtc = 0;
      temperature.always = 3200;
    };
    redshift-ext = {
      settings.randr.crtc = 1;
      temperature.always = 3600;
      # temperature.always = 4800;
    };
  };

  ## nix settings
  nix.package = pkgs.nix;
  nix.settings = {
    max-jobs = "auto";
    
    ## need to set `trusted-substituters` in `/etc/nix/nix.conf`
    extra-substituters = "https://mirrors.tuna.tsinghua.edu.cn/nix-channels/store";
    # extra-substituters = "https://mirror.sjtu.edu.cn/nix-channels/store";
  };
  nix.extraOptions = ''

    ## ... config follows from `/etc/nix/nix.conf`
    ## ... see also: man nix.conf
    ## ... https://nixos.org/manual/nix/stable/#sec-conf-file

    # vim: set ft=nix:'';

  ## ~/.config/nix/registry.json
  ## ... pin here if don't want to update
  ## ... otherwise, manage dynamically with `nix registry pin`
  # nix.registry = {

  #   nixpkgs.to = {
  #     type = "github";
  #     owner = "NixOS";
  #     repo = "nixpkgs";
  #     ref = "master";

  #     # for `getoptions`
  #     rev = "9b877f245d19e5bc8c380c91b20f9e2978c74d4a";
  #   };

  # };
}
