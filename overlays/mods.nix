final: prev:

{ ## be careful of `rec`, might not work

  biber217 = final.closurePackage {
    inherit (prev.biber) pname;
    version = "2.17";
    fromPath = /nix/store/pbv19v0mw57sxa7h6m1hzjvv33mdxxdf-perl5.36.0-biber-2.17;
  };

  tectonic-with-biber = prev.callPackage ../pkgs/tectonic-with-biber {
    biber = final.biber217;
  };

  fcitx5-configtool =
    prev.libsForQt5.callPackage ../pkgs/fcitx5-configtool.nix {
      kcmSupport = false;
    };

  byobu-with-tmux = prev.callPackage (
    { byobu, tmux, symlinkJoin, emptyDirectory }:
    symlinkJoin {
      name = "byobu-with-tmux-${byobu.version}";
      paths = [
        tmux
        tmux.man
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
