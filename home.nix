{ pkgs, lib, attrs, ... }:

let

  packages = with pkgs; {

    /* some packages are better installed via system pacman, e.g.
      - zsh: better be under root to be set the default shell
      - neovim: as the editor for sudoedit
      - nix: the daemon
    */

    os.basic = [
      ## <nixpkgs> pkgs/stdenv/generic/common-path.nix
      coreutils util-linux findutils diffutils
      gnused gnugrep gnumake
      which tree file procps
    ];

    nix.basic = [
      nixVersions.nix_2_17  # manage itself ## daemon managed by root
      cachix
      nix-tree
    ];

    nix.dev = [
      nil  # language server
      nixpkgs-fmt  # the official (?) formatter
      nixpkgs-hammering
      hydra-check
      # nixd  # better? language server ## not stable
      # nvd  # version diff
    ];

    cli.basic = [
      devbox
      bat
      fzf
      byobu-with-tmux
      diff-so-fancy
      git
      chezmoi
      age
      fd
      progress
      tldr
      zoxide
      lsof
      wget
      trash-cli
      mosh
      openssh  # need to unset SSH_AUTH_SOCK, maybe
      # trashy  # better, but its zsh completion is broken

      (writeShellScriptBin "proxychains" ''exec proxychains4 "$@"'')
      (binaryFallback "proxychains4" proxychains-ng)
      (binaryFallback "aria2c" aria2)
    ];

    cli.dev = [
      jq
      jc
      direnv
      shellcheck
      rtx
      fuse-overlayfs
      cargo-binstall  # then `cargo binstall cargo-quickinstall`
      # evcxr  # too heavy, instead `cargo quickinstall evcxr_repl`
      # watchman  # as git fsmonitor, gigantic deps
      nodejs  # required by coc.nvim
      # getoptions  # shell argument parser

      (inetutils.overrideAttrs (prev: {
        meta = prev.meta // {
          priority = 7;
          ## ^ lower than: default = 5; util-linux = 6;
        };
      }))  # telnet
    ];

    cli.app = [
      circumflex  # hacker news terminal
      uxplay  # airplay server
      tectonic-with-biber  # from `nixpkgs-follows`
    ];

    cli.python = let
      python3Packages = python310Packages;
      /* <nixpkgs> pkgs/top-level/aliases.nix
          pythonPackages = python.pkgs;
          python = python2;
      */
    in [
      ### do NOT expose python itself for safety reasons
      python3Packages.ipython
      python3Packages.ruff-lsp  ruff  # exposes `ruff`
      python3Packages.jedi-language-server
      poetry
    ];

    gui.app = [
      pulsar  # atom fork
      gimp-with-plugins

      gnomeExtensions.caffeine
      gnomeExtensions.kimpanel

      ## vscode
      (binaryFallback "code" (writeShellScriptBin "code" ''exec echo "$@"''))
    ];

  };

in {

  home.username = attrs.username;
  home.homeDirectory = attrs.homeDirectory;

  home.packages = with packages;
    os.basic ++
    nix.basic ++
    nix.dev ++
    cli.basic ++
    cli.dev ++
    cli.app ++
    cli.python ++
    gui.app ++
  [
    ## It is sometimes useful to fine-tune packages, for example, by applying
    ## overrides. You can do that directly here, just don't forget the
    ## parentheses:
    # (pkgs.nerdfonts.override { fonts = [ "FantasqueSansMono" ]; })

    ## You can also create simple shell scripts directly inside your
    ## configuration. For example, this adds a command 'my-hello' to your
    ## environment:
    # (pkgs.writeShellScriptBin "my-hello" ''
    #   echo "Hello, ${config.home.username}!"
    # '')
  ];

  imports = [
    ./modules/redshift-many
    ./modules/v2ray-ctrl
    ./modules/nixpkgs-helpers
    ./modules/flake-channels.nix
  ];

  programs.v2ray-ctrl = {
    # enable = false;
    outbounds = "dal6";
    # routings =
    #   "private-direct,cn-direct,tencent-direct,ms-transit,zoom-transit";
  };

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

  programs.xrandr-brightness = {
    output = "DP-1";
    # output = "HDMI-1";
  };

  programs.nixpkgs-helpers.viewer = "code --goto";

  ## uncomment to use system manpage
  # programs.man.enable = false;

  disabledModules = [

    ## https://github.com/nix-community/home-manager/issues/2333
    ## https://github.com/nix-community/home-manager/blob/master/modules/config/i18n.nix
    ## use system locale; see `sessionVariables`
    "config/i18n.nix"

  ];

  ## nix settings
  nix.package = pkgs.nix;  ## necessary for `nix show-config`
  nix.settings = {
    max-jobs = "auto";
    
    ## need to set `trusted-users = @wheel` in `/etc/nix/nix.conf`
    # tarball-ttl = 4294967295;
    auto-optimise-store = true;
    extra-substituters = [  ## with `?priority`
      "https://mirrors.tuna.tsinghua.edu.cn/nix-channels/store?priority=20"
      # "https://mirror.sjtu.edu.cn/nix-channels/store?priority=20"
    ];
  };
  nix.extraOptions = ''

    ## ... config follows from `/etc/nix/nix.conf`
    ## ... see also: man nix.conf
    ## ... https://nixos.org/manual/nix/stable/#sec-conf-file

    # vim: set ft=nix:''
  ;

  home.file = {
    ## override /usr/lib/environment.d/nix-daemon.conf
    ".config/environment.d/nix-daemon.conf".text = "";

    ## Building this configuration will create a copy of 'dotfiles/screenrc' in
    ## the Nix store. Activating the configuration will then make '~/.screenrc' a
    ## symlink to the Nix store copy.
    # ".screenrc".source = dotfiles/screenrc;

    ## You can also set the file content immediately.
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

    ## use system locale; see `disabledModules`
    LOCALE_ARCHIVE = "/usr/lib/locale/locale-archive";

    # ## override /usr/lib/environment.d/nix-daemon.conf
    # NIX_PATH = "nixpkgs=${pkgs.outPath}";
  };

  home.activation.userScript
    = lib.hm.dag.entryAfter [ "installPackages" ] ''
        flake=''${FLAKE_CONFIG_URI%#*}
        flakePath=$(
          nix eval --raw --impure --expr "builtins.getFlake $flake" | xargs
        )
        "$flakePath/activate.sh"  ## ^ `$flake` defined above
      '';

  # This value determines the Home Manager release that your configuration is
  # compatible with. This helps avoid breakage when a new Home Manager release
  # introduces backwards incompatible changes.
  #
  # You should not change this value, even if you update Home Manager. If you do
  # want to update the value, then make sure to first check the Home Manager
  # release notes.
  home.stateVersion = "22.11"; # Please read the comment before changing.

  ## let Home Manager install and manage itself.
  programs.home-manager.enable = true;


  ## does not work well with non-nix host
  # i18n.inputMethod = {
  #   enabled = "fcitx5";
  #   fcitx5.addons = with pkgs; [
  #     ## https://github.com/NixOS/nixpkgs/blob/master/pkgs/tools/inputmethods/fcitx5/with-addons.nix
  #     fcitx5-chinese-addons
  #   ];
  # };

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
