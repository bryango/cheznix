{
  description = "nixpkgs with personalized config";

  inputs = {

    nixpkgs.url = "nixpkgs";  ## flake registry: nixpkgs/nixpkgs-unstable
 
    /* alternatively,
      - use `master`, which is slightly more advanced;
      - pin to hash, e.g. "nixpkgs/a3a3dda3bacf61e8a39258a0ed9c924eeca8e293";
        ^ note that this is once problematic, but I cannot reproduce
        ^ find nice snapshots from hydra builds:
          https://hydra.nixos.org/jobset/nixpkgs/trunk/evals
    */

    ## python2 marked insecure: https://github.com/NixOS/nixpkgs/pull/201859
    nixpkgs_python2 = {
      ## ... pin to a cached build:
      url = "github:NixOS/nixpkgs/27bd67e55fe09f9d68c77ff151c3e44c4f81f7de";
      follows = "nixpkgs";
      ## ^ toggle to follow `nixpkgs`
    };

  };

  outputs = { self, nixpkgs, ... } @ inputs:
  let

    lib = nixpkgs.lib;
    mySystems = [ "x86_64-linux" ];
    forMySystems = lib.genAttrs mySystems;

    config = {
      ## https://github.com/nix-community/home-manager/issues/2954
      ## ... home-manager/issues/2942#issuecomment-1378627909
      allowBroken = true;
      allowUnfree = true;

      permittedInsecurePackages = [
        "python-2.7.18.6"
        "python-2.7.18.6-env"
      ];
    };

    genOverlay = system:
    let

      pkgs_python2 = import inputs.nixpkgs_python2 {
        inherit system config;
      };

      biber217 = {
        version = "2.17";
        outPath = builtins.fetchClosure {
          /* experimental:
            - after: https://github.com/NixOS/nix/pull/8370
            - need latest static: https://hydra.nixos.org/build/229213111

            nix profile install \
              /nix/store/ik8hqwxhj1q9blqf47rp76h7gw7s3060-nix-2.17.1-x86_64-unknown-linux-musl

            - /etc/nix/nix.conf: extra-experimental-features = fetch-closure
            - systemctl restart nix-daemon.service
          */
          inputAddressed = true;
          fromStore = "https://cache.nixos.org";
          fromPath = /nix/store/pbv19v0mw57sxa7h6m1hzjvv33mdxxdf-perl5.36.0-biber-2.17;
          ## ^ from: https://hydra.nixos.org/build/202359527#tabs-details
        };
      };

    in final: prev: let

      inherit (prev)
        callPackage
        recurseIntoAttrs;

      hostSymlinks = recurseIntoAttrs (callPackage ./pkgs/host-links.nix {});

      collectFlakeInputs = name: flake: {
        ${name} = flake;
      } // lib.concatMapAttrs collectFlakeInputs (flake.inputs or {});
      ## https://github.com/NixOS/nix/issues/3995#issuecomment-1537108310

    in { ## be careful of `rec`, might not work

      inherit collectFlakeInputs;
      flakeInputs = collectFlakeInputs "nixpkgs-config" self;

      ## exec "$name" from system "$PATH"
      ## if not found, fall back to "$package/bin/$name"
      binaryFallback = name: package: callPackage ./pkgs/binary-fallback {
          inherit name package;
        };

      ## create "bin/$name" from a template
      ## with `pkgs.substituteAll attrset`
      binarySubstitute = name: attrset: prev.writeScriptBin name (
        builtins.readFile (prev.substituteAll attrset)
      );

      ## some helper functions
      nixpkgs-helpers = callPackage ./pkgs/nixpkgs-helpers {};

      gimp = prev.gimp.override {
        withPython = true;
        python2 = pkgs_python2.python2;
      };

      tectonic-with-biber = callPackage ./pkgs/tectonic-with-biber.nix {
        biber = biber217;
      };

      fcitx5-configtool =
        prev.libsForQt5.callPackage ./pkgs/fcitx5-configtool.nix {
          kcmSupport = false;
        };

      byobu-with-tmux = callPackage (
        { byobu, tmux, symlinkJoin, emptyDirectory }:
        symlinkJoin {
          name = "byobu-with-tmux-${byobu.version}";
          paths = [
            tmux
            (byobu.override {
              textual-window-manager = tmux;
              screen = emptyDirectory;
              vim = emptyDirectory;
            })
          ];
          inherit (byobu) meta;
        }
      ) {};

      ## links to host libraries
      inherit hostSymlinks;
      inherit (hostSymlinks)
        host-usr
        host-locales;

      ## exposes nixpkgs source, i.e. `outPath`, in `pkgs`
      inherit (nixpkgs) outPath;

      ## helper function to gather overlaid packages, defined below
      inherit gatherOverlaid;

    };

    gatherOverlaid = system: final: prev: let

      overlaid = genOverlay system final prev;
      derivable = lib.filterAttrs (name: lib.isDerivation) overlaid;

      userOverlaid = "user-overlaid";
      inherit (prev) linkFarm;

    in {
      ${userOverlaid} = linkFarm userOverlaid derivable;
    };

  in {

    overlays = forMySystems genOverlay;

    legacyPackages = forMySystems (system: import nixpkgs {
      inherit system config;
      overlays = [
        (genOverlay system)
        (gatherOverlaid system)
      ];
    });

    lib = lib.recursiveUpdate lib {
      systems.flakeExposed = mySystems;
      inherit
        mySystems
        forMySystems;
    };

  };
}
