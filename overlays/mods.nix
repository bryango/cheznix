final: prev:

{ ## be careful of `rec`, might not work

  tectonic = final.callPackage ../pkgs/tectonic-lock-bundle {
    tectonic = prev.tectonic;
  };

  folly = prev.folly.overrideAttrs (prev: {
    outputs = [ "out" "dev" ];
    postFixup = ''
      substituteInPlace $dev/lib/cmake/folly/folly-targets-release.cmake  \
          --replace '$'{_IMPORT_PREFIX}/lib/ $out/lib/
    '';
    cmakeFlags = (prev.cmakeFlags or []) ++ [
      # ensure correct dirs in $dev/lib/pkgconfig/libfolly.pc
      # see https://github.com/NixOS/nixpkgs/issues/144170
      "-DCMAKE_INSTALL_INCLUDEDIR=include"
      "-DCMAKE_INSTALL_LIBDIR=lib"
    ];
  });

  # trigger build farm by `gatherOverlaid`
  watchman = prev.watchman;

  pulsar = prev.pulsar.overrideAttrs (prev: {
    version = "1.111.0";
    src = builtins.fetchClosure {
      /* artifact:
          https://github.com/pulsar-edit/pulsar/actions/runs/6886278991?pr=807
        - `nix store add-file` => `$storePath`
        - `echo "$storePath" | cachix push chezbryan`
        - `cachix pin chezbryan pulsar-source "$storePath"`
        - `nix store make-content-addressed`
      */
      fromStore = "https://chezbryan.cachix.org";
      fromPath = /nix/store/il7gx5f4arhhar3qkqkhqg05aissnf41-Linux.pulsar-1.111.0.tar.gz;
      toPath = /nix/store/7s486dgpwzdrrgnh7inhkcff3r44qwh9-Linux.pulsar-1.111.0.tar.gz;
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
