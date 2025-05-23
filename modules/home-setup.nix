{ attrs, config, lib, pkgs, ... }:

let

  inherit (pkgs.hostPlatform) isDarwin isLinux;

in

{
  config = {

    home = {

      ## install and manage home-manager itself, with the binary from nixpkgs
      packages = [ pkgs.home-manager ];

      username = attrs.username;
      homeDirectory = attrs.homeDirectory or (
        if isDarwin
        then "/Users/${attrs.username}"
        else "/home/${attrs.username}"
      );

      file = lib.optionalAttrs isLinux {
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
        export hmConfigRef="${attrs.username}@${attrs.hostname}"
        if [[ $flake == path:* ]] || [[ $flake == /* ]]; then
          flakePath=$(
            nix eval --raw --impure \
              --expr "toString (builtins.getFlake (toString \"$flake\"))" \
              | xargs
          )  ## the /nix/store path of $flake
          "$flakePath/activate.sh"
        else
          # guard against illegal flake refs
          >&2 echo "nix registry: illegal home-manager \$FLAKE_CONFIG_URI: $flake"
        fi
      '';

    };

    # just copy instead of linking darwin apps
    targets.darwin.linkApps.enable = false;
    home.activation.copyDarwinApps = lib.mkIf pkgs.stdenv.isDarwin (
      let
        apps = pkgs.buildEnv {
          name = "home-manager-applications";
          paths = config.home.packages;
          pathsToLink = "/Applications";
        };
      in lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        baseDir="${config.targets.darwin.linkApps.directory}"
        if [ -d "$baseDir" ]; then
          rm -rf "$baseDir"
        fi
        mkdir -p "$baseDir"
        for appFile in ${apps}/Applications/*; do
          target="$baseDir/$(basename "$appFile")"
          $DRY_RUN_CMD cp ''${VERBOSE_ARG:+-v} -fHRL "$appFile" "$baseDir"
          $DRY_RUN_CMD chmod ''${VERBOSE_ARG:+-v} -R +w "$target"
        done
      ''
    );

    nix.extraOptions = ''

      ## ... config follows from `/etc/nix/nix.conf`
      ## ... see also: man nix.conf
      ## ... https://nixos.org/manual/nix/stable/#sec-conf-file

      # vim: set ft=nix:''
    ;



  };
}
