final: prev:

with prev;

{
  ## be careful of `rec`, might not work

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

  nodejs_16 = (nodejs_16.override {
    /** fixes:
      Node.js configure: Found Python 3.12.4...
      Please use python3.11 or python3.10 or python3.9 or python3.8 or python3.7 or python3.6.
    */
    python3 = python311;
  }).overrideAttrs ({ checkTarget, passthru, ... }: {
    /** disable flaky tests; see e.g.
      https://github.com/NixOS/nixpkgs/commit/d25d9b6a2dc90773039864bbf66c3229b6227cde
    */
    checkTarget = lib.replaceStrings [ "test-ci-js" ] [ "" ] checkTarget;
  });
  grammarly-languageserver = final.nodejs_16.pkgs.grammarly-languageserver;

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
