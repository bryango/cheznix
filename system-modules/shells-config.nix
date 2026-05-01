/**
  NixOS configuration for shells, compatible with system-manager
*/

{
  environment = {
    shellAliases = {
      ls = "ls --color=auto";
      ll = "ls -alhF --group-directories-first";
      rm = "rm -iv";
      cp = "cp -i";
      mv = "mv -i";
    };
    interactiveShellInit = ''
      ${builtins.readFile ./scripts/vi-history.sh}
    '';
  };

  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
  };

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
    loginShellInit = builtins.readFile ./scripts/etc-profile.zsh;
  };
}
