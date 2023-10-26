final: prev:

{ ## be careful of `rec`, might not work

  biber217 = final.closurePackage {
    inherit (prev.biber) pname;
    version = "2.17";
    fromPath = /nix/store/pbv19v0mw57sxa7h6m1hzjvv33mdxxdf-perl5.36.0-biber-2.17;
    ## ^ nix eval --raw --no-write-lock-file ../pkgs/tectonic-with-biber#biber
  };

  pulsar = final.closurePackage {
    inherit (prev.pulsar) pname;
    version = "1.109.0";
    /* last build of pulsar before marked insecure
        https://hydra.nixos.org/build/237386313
    */
    fromPath = /nix/store/mqk6v4p5jzkycbrs6qxgb2gg4qk6h3p1-pulsar-1.109.0;
  };

  tectonic-with-biber = prev.callPackage ../pkgs/tectonic-with-biber {
    biber = final.biber217;
  };

  /* ## not used by me, disabled to save build time
  fcitx5-configtool =
    prev.libsForQt5.callPackage ../pkgs/fcitx5-configtool.nix {
      kcmSupport = false;
    };
  */

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
