{ pkgs, ... }:

let

  packages = with pkgs; {

    /* some packages are better installed via system pacman, e.g.
      - zsh: better be under root to be set the default shell
      - neovim: as the editor for sudoedit
      - nix: the daemon
      these can be managed with `system-manager` once it stabilizes.
    */

    os.basic = [
      ## <nixpkgs> pkgs/stdenv/generic/common-path.nix
      coreutils util-linux findutils diffutils iputils
      gnused gnugrep gnumake
      which tree file procps
    ];

    nix.basic = [
      nix  # manage itself ## daemon managed by root
      cachix
      nix-tree
      system-manager
    ];

    nix.dev = [
      nil  # language server
      nixpkgs-fmt  # the official (?) formatter
      nixpkgs-hammering
      nixpkgs-review
      hydra-check
      nix-diff
      # nixd  # better? language server ## not stable
      # nvd  # version diff
    ];

    cli.basic = [
      (neovim.override { withRuby = false; })
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

      proxychains
      # (binaryFallback "proxychains4" proxychains-ng)
      (writeShellScriptBin "proxychains" ''exec proxychains4 "$@"'')
      (binaryFallback "aria2c" aria2)
    ];

    cli.dev = [
      difftastic
      jq
      jc
      direnv
      shellcheck
      rtx
      nodejs  # required by coc.nvim
      cargo-binstall  # then `cargo binstall cargo-quickinstall`
      # evcxr  # too heavy, instead `cargo quickinstall evcxr_repl`
      # watchman  # as git fsmonitor, gigantic deps
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
      fuse-overlayfs
    ];

    cli.python = let
      inherit python3Packages;
      /* <nixpkgs> pkgs/top-level/aliases.nix
          pythonPackages = python.pkgs;
          python = python2;
      */
    in [
      ### do NOT expose python itself for safety reasons
      python3Packages.ipython
      python3Packages.ruff-lsp  ruff  # exposes `ruff`
      (closurePackage {
        inherit (pkgs.jedi-language-server) pname;
        version = "0.40.0";
        /* last build of pulsar before broken
            https://hydra.nixos.org/build/238821194
            https://github.com/NixOS/nixpkgs/issues/263493
        */
        fromPath = /nix/store/lb2y012m1nckzgw2a408zzaxn1cgg5vd-python3.11-jedi-language-server-0.40.0;
      })
      poetry
    ];

    gui.app = [
      (closurePackage {
        inherit (pkgs.pulsar) pname;
        version = "1.109.0";
        /* last build of pulsar before marked insecure
            https://hydra.nixos.org/build/237386313
        */
        fromPath = /nix/store/mqk6v4p5jzkycbrs6qxgb2gg4qk6h3p1-pulsar-1.109.0;
      })  # atom fork
      gimp-with-plugins

      gnomeExtensions.caffeine
      gnomeExtensions.kimpanel

      ## vscode dummy:
      (binaryFallback "code" (writeShellScriptBin "code" ''exec echo "$@"''))
    ];

  };

in {

  imports = [
    ./modules/redshift-many
    ./modules/v2ray-ctrl
    ./modules/nixpkgs-helpers
    ./modules/flake-channels.nix
    ./modules/home-setup.nix
    ## ^ process & pass home attrs with basic setup
  ];

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

  programs.v2ray-ctrl = {
    # enable = false;
    outbounds = "la6";
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

  programs.nixpkgs-helpers.viewer = "echo code --goto";

  programs.man = {
    enable = true;  ## `disable` to use system manpage
    package = pkgs.closurePackage {
      inherit (pkgs.man) pname;
      version = "2.11.2";
      /* last build of man-db with groff<1.23
          https://hydra.nixos.org/build/229015976
      */
      fromPath = /nix/store/16v2fg1yz5k8b0h869aq31w6b3gwn38w-man-db-2.11.2;
    };
  };

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

  home.file = {
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
    ## use system locale; see `disabledModules`
    LOCALE_ARCHIVE = "/usr/lib/locale/locale-archive";

    # EDITOR = "nvim";
    # NIX_PATH = "nixpkgs=${pkgs.outPath}";
  };

  # This value determines the Home Manager release that your configuration is
  # compatible with. This helps avoid breakage when a new Home Manager release
  # introduces backwards incompatible changes.
  #
  # You should not change this value, even if you update Home Manager. If you do
  # want to update the value, then make sure to first check the Home Manager
  # release notes.
  home.stateVersion = "22.11"; # Please read the comment before changing.


  ## does not work well with non-nix host
  # i18n.inputMethod = {
  #   enabled = "fcitx5";
  #   fcitx5.addons = with pkgs; [
  #     ## https://github.com/NixOS/nixpkgs/blob/master/pkgs/tools/inputmethods/fcitx5/with-addons.nix
  #     fcitx5-chinese-addons
  #   ];
  # };

}
