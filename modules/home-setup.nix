{ attrs, config, ... }:

{
  config = {
    home = {
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

    };

  };
}
