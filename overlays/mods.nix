final: prev:

{ ## be careful of `rec`, might not work

  biber217 = final.closurePackage {
    inherit (prev.biber) pname;
    version = "2.17";
    fromPath = /nix/store/pbv19v0mw57sxa7h6m1hzjvv33mdxxdf-perl5.36.0-biber-2.17;
    ## ^ nix eval --raw --no-write-lock-file ../pkgs/tectonic-with-biber#biber
  };

  perl539 = (prev.perl538.override {
    self = final.perl539;
    version = "5.39.5";
    sha256 = "sha256-OeT434PLdH7fPhegovjuEDU7oWcptmXNUEfOwnIvbtE=";
  }).overrideAttrs (prevAttrs: {
    patches = [];
  });

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
