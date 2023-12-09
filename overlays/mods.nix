final: prev:

{ ## be careful of `rec`, might not work

  biber217 = let version = "2.17"; in (
    prev.biber.override {
      texlive.pkgs.biber.texsource =  {
        inherit version;
        inherit (prev.biber) pname meta;
      };
    }
  ).overrideAttrs {
    src = prev.fetchFromGitHub {
      owner = "plk";
      repo = "biber";
      rev = "v${version}";
      hash = "sha256-Tt2sN2b2NGxcWyZDj5uXNGC8phJwFRiyH72n3yhFCi0=";
    };
    patches = [
      (prev.fetchpatch {
        url = "https://patch-diff.githubusercontent.com/raw/plk/biber/pull/411.patch";
        hash = "sha256-osgldRVfe3jnMSOMnAMQSB0Ymc1s7J6KtM2ig3c93SE=";
      })
    ];
  };

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
