final: prev:

with prev;

{
  ## be careful of `rec`, might not work

  git-master = git.overrideAttrs (prevAttrs: {
    version = "2.45.2-unstable-2024-06-15";
    src = fetchFromGitHub {
      owner = "git";
      repo = "git";
      rev = "d63586cb314731c851f28e14fc8012988467e2da";
      hash = "sha256-/8agQ6bIVYChBcEJNvr/TyV+SzrwAJpwchU+3dhJcpg=";
    };
    nativeBuildInputs = (prevAttrs.nativeBuildInputs or [ ]) ++ [ autoreconfHook ];
    preAutoreconf = (prevAttrs.preAutoreconf or "") + ''
      make configure # run autoconf to generate ./configure from master
    '';
  });

  # git-branchless-master = callPackage ../pkgs/git-branchless.nix {
  #   inherit (darwin.apple_sdk.frameworks) Security SystemConfiguration;
  #   git = final.git-master;
  # };

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
