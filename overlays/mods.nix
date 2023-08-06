final: prev:

{ ## be careful of `rec`, might not work

  fcitx5-configtool =
    prev.libsForQt5.callPackage ./../pkgs/fcitx5-configtool.nix {
      kcmSupport = false;
    };

  byobu-with-tmux = prev.callPackage (
    { byobu, tmux, symlinkJoin, emptyDirectory }:
    symlinkJoin {
      name = "byobu-with-tmux-${byobu.version}";
      paths = [
        tmux
        (byobu.override {
          textual-window-manager = tmux;
          screen = emptyDirectory;
          vim = emptyDirectory;
        })
      ];
      inherit (byobu) meta;
    }
  ) {};

}
