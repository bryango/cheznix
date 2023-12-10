final: prev:

{ ## be careful of `rec`, might not work

  pulsar = prev.pulsar.overrideAttrs (prev: {
    version = "1.110.0";
    src = builtins.fetchClosure {
      /* artifact:
          https://github.com/pulsar-edit/pulsar/actions/runs/6527478252?pr=766
        - `nix store add-file`
        - `nix store make-content-addressed` => `$storePath`
        - `echo "$storePath" | cachix push chezbryan`
      */
      fromStore = "https://chezbryan.cachix.org";
      fromPath = /nix/store/slcqsdm5pmx3f1lz56pzd5anz2fnmjhl-Linux.pulsar-1.110.0.tar.gz;
      toPath = /nix/store/zs6h3bsw8xmbmxb3rmhqvgqsb9z5szpy-Linux.pulsar-1.110.0.tar.gz;
    };
  });

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
