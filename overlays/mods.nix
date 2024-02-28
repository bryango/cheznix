final: prev:

with prev;

{ ## be careful of `rec`, might not work

  pulsar = pulsar.overrideAttrs (prev: {
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
      fromPath = /nix/store/7s486dgpwzdrrgnh7inhkcff3r44qwh9-Linux.pulsar-1.111.0.tar.gz;
    };
  });

  /* ## not used by me, disabled to save build time
  fcitx5-configtool =
    libsForQt5.callPackage ../pkgs/fcitx5-configtool.nix {
      kcmSupport = false;
    };
  */

  byobu-with-tmux = callPackage (
    { byobu, tmux, symlinkJoin, emptyDirectory }:
    symlinkJoin {
      name = "byobu-with-tmux-${byobu.version}";
      paths = [
        tmux
        tmux.man
        (byobu.override {
          screen = emptyDirectory;
          vim = emptyDirectory;
        })
      ];
      inherit (byobu) meta;
    }
  ) {};

}
