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
    ./shells-config.nix
    ./nix-conf.nix
  ]
  ++ map (path: nixosModulesPath + path) [
    ## NixOS modules, with a leading "/"
    "/programs/zsh/zsh.nix"
    "/programs/zsh/oh-my-zsh.nix"
    "/programs/zsh/zsh-autosuggestions.nix"
    "/programs/zsh/zsh-syntax-highlighting.nix"
    "/programs/neovim.nix"
  ];

  config = {
    users.mutableUsers = true; # preserve existing users
    users.users.bryan = {
      isNormalUser = true;
      group = "bryan"; # must set! consistent for arch
      extraGroups = [
        "users"
        "wheel"
      ];
      shell = pkgs.zsh;
    };
    users.groups.bryan = { };
    system-manager.allowAnyDistro = true;
    nixpkgs.hostPlatform = pkgs.stdenv.hostPlatform.system;

    # environment.systemPackages = with pkgs; [
    #   zsh
    #   neovim
    #   nix
    # ];  ## wait for better ecosystem support

  };
}
