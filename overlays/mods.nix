final: prev:

with prev;

{ ## be careful of `rec`, might not work

  pulsar = pulsar.overrideAttrs (prev: {
    version = "1.111.0";
    src = builtins.fetchClosure {
      /** Pulsar follows a semi-automated release process. Look under github
          actions for the [artifact] corresponding to the release [commit].
          
          [artifact]: https://github.com/pulsar-edit/pulsar/actions/runs/7925816294
          [commit]: https://github.com/pulsar-edit/pulsar/tree/v1.114.0

          - nix store add-path
          - cachix push chezbryan
          - cachix pin chezbryan pulsar-source
          - nix store make-content-addressed

          See also: https://github.com/NixOS/nix/issues/6210#issuecomment-1060834892
      */
      # fromPath = /nix/store/6jbqzpyjzdfbpz5qc6rijs554kfz84ry-Linux.pulsar-1.114.0.tar.gz;
      fromPath = /nix/store/yzan1f59qslr9sygqrlxlmslmpnknn0j-Linux.pulsar-1.114.0.tar.gz;
      fromStore = "https://chezbryan.cachix.org";
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
