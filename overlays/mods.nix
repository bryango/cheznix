final: prev:

with prev;

{
  ## be careful of `rec`, might not work

  ## inherit to trigger ci builds
  inherit
    gitbutler
    nodejs_16;
  inherit (nodejs_16.pkgs) grammarly-languageserver;

  texstudio-lazy_resize = texstudio.overrideAttrs ({ patches ? [], ... }: {
    pname = "texstudio-lazy_resize";
    patches = patches ++ [
      (fetchpatch2 {
        name = "do-not-resize-pdf-after-rebuilds.patch";
        url = "https://github.com/texstudio-org/texstudio/compare/master...bryango:master.patch";
        hash = "sha256-KN2oTeNljgYjbvta96uwZnKUFZu+6IIUBIaNwIcGwvw=";
      })
    ];
  });

  git-master = lib.dontDistribute (git.overrideAttrs ({ nativeBuildInputs ? [ ], preAutoreconf ? "", meta ? { }, ... }: {
    version = "2.46.0-unstable-2024-07-29";
    src = fetchFromGitHub {
      owner = "git";
      repo = "git";
      rev = "ad57f148c6b5f8735b62238dda8f571c582e0e54";
      hash = "sha256-CeC3YnFMNE9bmb3f0NGEH0gdioTtMfdLfYAhi63tWdc=";
    };
    nativeBuildInputs = nativeBuildInputs ++ [ autoreconfHook ];
    preAutoreconf = preAutoreconf + ''
      make configure # run autoconf to generate ./configure from master
    '';
  }));

  pulsar = callPackage ../pkgs/pulsar-from-ci.nix { inherit pulsar; };

  ## no longer used by me, disabled to save build time
  fcitx5-configtool = lib.dontDistribute
    (libsForQt5.callPackage ../pkgs/unused/fcitx5-configtool.nix {
      kcmSupport = false;
    });

  byobu-with-tmux = symlinkJoin {
    name = "byobu-with-tmux-${byobu.version}";
    paths = [
      tmux
      tmux.man
      (byobu.override {
        screen = null;
        vim = null;
      })
    ];
    meta = (byobu.meta or { }) // {
      description = "Byobu with only the Tmux backend";
    };
  };

}
