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
    ## ... pin to a cached build:
    nixpkgs_python2.url = "github:NixOS/nixpkgs/7e63eed145566cca98158613f3700515b4009ce3";

    nixpkgs_biber217.url = "github:NixOS/nixpkgs/40f79f003b6377bd2f4ed4027dde1f8f922995dd";
    ## ... from: https://hydra.nixos.org/build/202359527

  };

  outputs = { self, nixpkgs, ... } @ inputs:
  let

    lib = nixpkgs.lib;
    mySystems = [ "x86_64-linux" ];
    forMySystems = lib.genAttrs mySystems;

    collectFlakeInputs = name: flake: {
      ${name} = flake;
    } // lib.concatMapAttrs collectFlakeInputs (flake.inputs or {});
    ## https://github.com/NixOS/nix/issues/3995#issuecomment-1537108310

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

      pkgs_biber217 = import inputs.nixpkgs_biber217 {
        inherit system config;
      };

    in final: prev: let

      inherit (prev)
        callPackage
        recurseIntoAttrs;

      hostSymlinks = recurseIntoAttrs (callPackage ./pkgs/host-links.nix {});

    in { ## be careful of `rec`, might not work

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
          biber = pkgs_biber217.biber;
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

      ## exposes nixpkgs source, i.e. `outPath`, in `pkgs`
      inherit (nixpkgs) outPath;

      ## helper function to gather overlaid packages, defined below
      inherit gatherOverlaid;

    } ## then we expose some subpackges:
    // hostSymlinks;

    userOverlaid = "user-overlaid";
    gatherOverlaid = system: final: prev: let

      overlaid = genOverlay system final prev;
      derivable = lib.filterAttrs (name: lib.isDerivation) overlaid;
      inherit (prev) linkFarm;

    in {
      ${userOverlaid} = linkFarm userOverlaid derivable;
    };

    legacyPackages = forMySystems (system: import nixpkgs {

      inherit system;
      config = {

        inherit (config)
          allowBroken
          allowUnfree
          permittedInsecurePackages;

      };

      overlays = [ (genOverlay system) ];
    });

  in {

    inherit legacyPackages;

    packages = forMySystems (
      system: lib.genAttrs [ userOverlaid ] (
        legacyPackages.${system}.extend (gatherOverlaid system)
      )
    );

    overlays = forMySystems genOverlay;

    lib = lib.recursiveUpdate lib {
      systems.flakeExposed = mySystems;
      inherit
        mySystems
        forMySystems
        collectFlakeInputs;
    };

  };
}
