{ attrs, ... }:

{
  imports = [
    # ./modules/direnv-exec-apps
    # ./modules/redshift-many
    # ./modules/v2ray-ctrl
    # ./modules/nixpkgs-helpers
    # ./modules/flake-channels.nix
    ../../modules/home-setup.nix
    ## ^ process & pass home attrs with basic setup
  ];

  home.username = attrs.username;
  home.stateVersion = "26.05";
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    oh-my-zsh.enable = true;
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
    history.size = 1000000;
    setOptions = [
      # same background '&' as in bash
      "NO_HUP"
      "NO_CHECK_JOBS"

      # trim history
      "HIST_FIND_NO_DUPS"
      "HIST_IGNORE_DUPS"
    ];
    initContent = ''
      export WORDCHARS='|'
      bindkey '' undo

      # ls when pwd changed
      chpwd() {
          ls --color=auto -alhF --group-directories-first >&2
          >&2 echo "$(tput bold)>> $PWD$(tput sgr0)"
      }

      # make available for other shells
      export FPATH

      PROMPT=$'\n%B> %* %(!.%F{red}.%F{green})%n%f@%F{yello}%m%f%b %~ %B%(?..%F{red}!%?)%f%b\n%(!.#.$) '
      setopt prompt_sp
    '';
  };
}
