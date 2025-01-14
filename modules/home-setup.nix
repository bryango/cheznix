{ attrs, config, lib, pkgs, ... }:

{
  config = {

    home = {

      ## install and manage home-manager itself, with the binary from nixpkgs
      packages = [ pkgs.home-manager ];

      username = attrs.username;
      homeDirectory = attrs.homeDirectory or "/home/${attrs.username}";

      file = {
        ## override /usr/lib/environment.d/nix-daemon.conf
        ".config/environment.d/nix-daemon.conf".text = "";
      };

      sessionVariables = {

        ## better `modules/misc/xdg-system-dirs.nix`
        ## .. see `modules/home-environment.nix`
        XDG_DATA_DIRS = "${config.home.profileDirectory}/share:\${XDG_DATA_DIRS:-/usr/local/share:/usr/share}";

      };

      activation.userScript = lib.hm.dag.entryAfter [ "installPackages" ] ''
        flake=''${FLAKE_CONFIG_URI%#*}
        flakePath=$(
          nix eval --raw --impure \
            --expr "toString (builtins.getFlake (toString $flake))" \
            | xargs
        )  ## the /nix/store path of $flake
        "$flakePath/activate.sh"
      '';

    };

    nix.extraOptions = ''

      ## ... config follows from `/etc/nix/nix.conf`
      ## ... see also: man nix.conf
      ## ... https://nixos.org/manual/nix/stable/#sec-conf-file

      # vim: set ft=nix:''
    ;



  };
}
