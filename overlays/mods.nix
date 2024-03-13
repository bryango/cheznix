final: prev:

with prev;

{
  ## be careful of `rec`, might not work

  ## to trigger ci build
  wechat-uos = wechat-uos;

  pulsar = pulsar.overrideAttrs
    (prev: {
      # version = "1.114.0";
      src =
        let
          /**
            Pulsar follows a semi-automated release process. Look under github
            actions for the [artifact] corresponding to the release [commit].
          
            [artifact]: https://github.com/pulsar-edit/pulsar/actions/runs/7925816294
            [commit]: https://github.com/pulsar-edit/pulsar/tree/v1.114.0

            - nix store add-path # NOT add-file, different hashing scheme
            - cachix push chezbryan
            - cachix pin chezbryan pulsar-source
            - nix store make-content-addressed

            See also: https://github.com/NixOS/nix/issues/6210#issuecomment-1060834892
          */
          path = /nix/store/yzan1f59qslr9sygqrlxlmslmpnknn0j-Linux.pulsar-1.114.0.tar.gz;
        in
        builtins.fetchClosure {
          fromStore = "https://chezbryan.cachix.org";
          /** it seems that cachix doesn't advertise ca-derivations;
              no worries, just treat them as input addressed: */
          toPath = path;
          fromPath = path;
        };
    });

  /* ## not used by me, disabled to save build time
    fcitx5-configtool =
    libsForQt5.callPackage ../pkgs/fcitx5-configtool.nix {
      kcmSupport = false;
    };
  */

  byobu-with-tmux = callPackage
    (
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
    )
    { };

}
