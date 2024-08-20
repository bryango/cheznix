final: prev:

with prev;

{
  ## be careful of `rec`, might not work

  ## inherit to trigger ci builds
  inherit
    gitbutler
    nodejs_16;
  inherit (nodejs_16.pkgs) grammarly-languageserver;

  git-master = git.overrideAttrs (prevAttrs: {
    version = "2.46.0-unstable-2024-07-29";
    src = fetchFromGitHub {
      owner = "git";
      repo = "git";
      rev = "ad57f148c6b5f8735b62238dda8f571c582e0e54";
      hash = "sha256-CeC3YnFMNE9bmb3f0NGEH0gdioTtMfdLfYAhi63tWdc=";
    };
    nativeBuildInputs = (prevAttrs.nativeBuildInputs or [ ]) ++ [ autoreconfHook ];
    preAutoreconf = (prevAttrs.preAutoreconf or "") + ''
      make configure # run autoconf to generate ./configure from master
    '';
  });

  pulsar = callPackage ../pkgs/pulsar-from-ci.nix { pulsar = pulsar; };

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
