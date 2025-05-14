/**
  _unique_ entrypoint for home-manager configurations
  ... across _all_ platforms
*/

{ pkgs, lib, config, ... }:

let

  inherit (pkgs.hostPlatform)
    isDarwin
    isLinux;

  packages = with pkgs; {

    /* some packages are better installed via system pacman, e.g.
      - zsh: better be under root to be set the default shell
      - neovim: as the editor for sudoedit
      - nix: the daemon
      these can be managed with `system-manager` once it stabilizes.
    */

    os.basic = [
      ## <nixpkgs> pkgs/stdenv/generic/common-path.nix
      coreutils util-linux findutils diffutils
      gnused gnugrep gnumake
      which tree file procps less
    ] ++ lib.optionals isLinux [
      iputils
    ];

    nix.basic = [
      config.nix.package  # manage itself ## daemon managed by root
      cachix
      nix-tree
      nix-diff
    ];

    nix.dev = [
      nil  # language server
      nixpkgs-fmt  # the unofficial formatter
      nixfmt-rfc-style  # the official formatter
      nurl  # generate fetcher call
      nix-init  # generate package
      nix-update
      nix-output-monitor
      nix-flake-tree # ./flake-tree.py
      nixpkgs-pr-checker # ./nixpkgs-config/pr-checker.sh
      nixpkgs-hammering
      nixpkgs-review
      # hydra-check
      # nixd  # future lsp ## not stable # needs llvmPackages.llvm.lib
      # nvd  # version diff
    ] ++ lib.optionals isLinux [
      system-manager  # to be stabilized
    ];

    cli.basic = [
      neovim
      jq
      bat
      fzf
      ripgrep
      byobu-with-tmux
      diff-so-fancy
      shellcheck
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
      git-branchless
      dust
      bottom
      jujutsu
      faketty
      openssh  # need to unset SSH_AUTH_SOCK, maybe
      # trashy  # better, but its zsh completion is broken

      (binaryFallback "aria2c" aria2)
      (writeShellScriptBin "proxychains" ''
        if command -v proxychains4 &>/dev/null; then
          exec proxychains4 "$@"
        fi
        if command -v env-proxy &>/dev/null; then
          exec env-proxy "$@"
        fi
        >&2 echo could not find "proxychains" or "env-proxy"
        exit 1
      '')
    ] ++ lib.optionals isLinux [
      stdoutisatty  # from nixpkgs-config
      proxychains
      # (binaryFallback "proxychains4" proxychains-ng)
    ];

    cli.dev = [
      aichat
      mosh
      difftastic
      jc
      rustc cargo clippy
      (lib.setPrio 3 rustup)
      cargo-binstall  # then `cargo binstall cargo-quickinstall`
      cargo-tarpaulin  # show test coverage
      cargo-nextest  # better test runner
      nodejs  # required by coc.nvim
      watchman  # as git fsmonitor
      # mise  # dev runtime manager
      # evcxr  # too heavy, instead `cargo quickinstall evcxr_repl`
      # getoptions  # shell argument parser
      # diffoscopeMinimal  # too heavy, use distro package instead
      # devbox  # cool but I am mostly using vanilla nix flake
    ] ++ lib.optionals isLinux [
      mold  # linker for non-nix projects; for nix, use `mold-wrapped`
            # ... currently broken on darwin
    ];

    cli.app = [
      gh
      circumflex  # hacker news terminal
      tectonic
      (writeShellScriptBin "biber-for-tectonic" ''exec ${lib.getExe tectonic.biber} "$@"'')
      inetutils # telnet
      dufs # file server
      (if isLinux then miktex else texliveSmall.withPackages (ps: with ps; [
        enumitem
        doublestroke
        todonotes
        nowidow
        helvetic
        comment
        uri
        tikz-cd
      ]))
      hunspellDicts.en_US-large
      hyphenDicts.en_US
    ] ++ lib.optionals isLinux [
      fuse-overlayfs
      uxplay  # airplay server
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
      python3Packages.jedi-language-server
      ruff  # exposes `ruff`
      poetry
      pipx
    ];

    gui.app = [
      remmina
      (gimp-with-plugins.override {
        plugins = # with gimpPlugins;
        [
          # # broken since removal of enum34
          # # https://github.com/NixOS/nixpkgs/pull/389263
          # resynthesizer
        ];
      })

      zed-editor
      texstudio-lazy_resize # fork from nixpkgs-config

      ## vscode dummy:
      (binaryFallback "code" (writeShellScriptBin "code" ''echo "$@"''))
    ] ++ lib.optionals isLinux [
      xorg.xinput
      pulsar  # atom fork

      nixgl.nixGLIntel
      nixgl.nixVulkanIntel
      (writeShellApplication {
        name = "zeditor";
        runtimeInputs = [
          zed-editor
          nixgl.nixVulkanIntel
        ];
        text = ''exec -a zeditor nixVulkanIntel zeditor "$@"'';
        meta.priority = (zed-editor.meta.priority or 5) - 1;
        # override the original zed binary
      })
    ] ++ lib.optionals isDarwin [
      darwin-apps # from ./overlay.nix
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
    outbounds = "dal4";
    # routings =
    #   "private-direct,cn-direct,tencent-direct,ms-transit,zoom-transit";
  };

  services.redshift-many = lib.optionalAttrs isLinux {
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

  programs.nixpkgs-helpers = {
    viewer = "echo code --goto";
    # flakeref = "nixpkgs";
  };

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
    # stdlib = "";
  };

  programs.man = {
    enable = true;  ## `disable` to use system manpage
  };

  disabledModules = [

    ## https://github.com/nix-community/home-manager/issues/2333
    ## https://github.com/nix-community/home-manager/blob/master/modules/config/i18n.nix
    ## use system locale; see `sessionVariables`
    "config/i18n.nix"

  ];

  ## nix settings
  ## must set for `nix.settings` and stuff
  nix.package = pkgs.nixPatched; # from `nixpkgs-config`
  nix.settings = {
    max-jobs = "auto";
    fallback = true;

    ## do _not_ cache negative substituter hits
    narinfo-cache-negative-ttl = 0;
    
    ## need to set `trusted-users = @wheel` in `/etc/nix/nix.conf`
    # tarball-ttl = 4294967295;
    auto-optimise-store = true;
    extra-substituters = [  ## with `?priority`
      "https://mirrors.tuna.tsinghua.edu.cn/nix-channels/store?priority=20"
      # "https://mirror.sjtu.edu.cn/nix-channels/store?priority=20"

      ## cachix use nix-community -O .
      "https://chezbryan.cachix.org"
      "https://nix-community.cachix.org"
    ];

    extra-trusted-public-keys = [
      "chezbryan.cachix.org-1:4n1STyrAtSfRth4sbgUCKfgjtgR8yIy40jIV829Lfow="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
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


  i18n.inputMethod = lib.optionalAttrs isLinux {
    enabled = "fcitx5";
    # one might also need to install native system integrations, e.g.
    # sudo pacman -S fcitx5-gtk
    fcitx5 = with pkgs; {
      # https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/i18n/input-method/fcitx5.nix
      # https://github.com/NixOS/nixpkgs/blob/master/pkgs/tools/inputmethods/fcitx5/with-addons.nix
      fcitx5-with-addons = qt6Packages.fcitx5-with-addons.override {
        fcitx5-configtool = fcitx5-configtool-no-kcm; # defined in nixpkgs-config
      };
      addons = [
        fcitx5-chinese-addons
      ];
    };
  };

}
