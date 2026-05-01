{
  pkgs,
  nixosModulesPath,
  cheznix,
  attrs,
  ...
}:

let
  /**
    modules migrated from nixpkgs upstream
  */
  upstreamModules = (cheznix.inputs.system-manager.outPath + "/nix/modules/upstream/nixpkgs");
in
{

  disabledModules = [
    ## currently broken so disabled:
    # upstreamModules
  ];

  imports = [
    ## non-NixOS modules
    # ./zsh.nix
    ./shells-env.nix
  ]
  ++ map (path: nixosModulesPath + path) [
    ## NixOS modules, with a leading "/"
    "/programs/zsh/zsh.nix"
    "/programs/zsh/oh-my-zsh.nix"
    "/programs/zsh/zsh-autosuggestions.nix"
    "/programs/zsh/zsh-syntax-highlighting.nix"
  ];

  config = {
    users.mutableUsers = true; # preserve existing users
    users.users.bryan = {
      isNormalUser = true;
      extraGroups = [ "wheel" ];
      shell = pkgs.zsh;
    };
    system-manager.allowAnyDistro = true;
    nixpkgs.hostPlatform = pkgs.stdenv.hostPlatform.system;
    programs.zsh = {
      enable = true;
      enableCompletion = true;
      enableBashCompletion = true;
      enableLsColors = true;
      autosuggestions.enable = true;
      ohMyZsh.enable = true;
      syntaxHighlighting = {
        enable = true;
        highlighters = [
          "main"
          "brackets"
          "pattern"
          "root"
          "line"
        ];
        styles.line = "bold";
        # styles.root = "";
      };
      histSize = 1000000;
      setOptions = [
        # same background '&' as in bash
        "NO_HUP"
        "NO_CHECK_JOBS"

        # trim history
        "HIST_FIND_NO_DUPS"
        "HIST_IGNORE_DUPS"
      ];
      # PROMPT=$'\n%B> %* %n@%F{yellow}%m%f%b %~ %(?..%F{red}!%?)%f%b\n%(!.#.$) '
      # PROMPT=$'\n%B%(!.%F{red}.%F{green})> %* %n@%F{yello}%m%(!.%F{red}.%F{green})%b %~ %(?..%F{red}!%?)%f%b\n%(!.#.$) '
      promptInit = ''
        PROMPT=$'\n%B> %* %(!.%F{red}.%F{green})%n%f@%F{yello}%m%f%b %~ %B%(?..%F{red}!%?)%f%b\n%(!.#.$) '
        setopt prompt_sp
      '';
      interactiveShellInit = ''
        export WORDCHARS='|'
        bindkey '' undo

        # ls when pwd changed
        chpwd() {
            ls --color=auto -alhF --group-directories-first >&2
            >&2 echo "$(tput bold)>> $PWD$(tput sgr0)"
        }

        # make available for other shells
        export FPATH
      '';
    };

    # environment.systemPackages = with pkgs; [
    #   zsh
    #   neovim
    #   nix
    # ];  ## wait for better ecosystem support

  };
}
