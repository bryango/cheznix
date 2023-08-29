{
  description = "nixpkgs with personalized config";

  inputs = {

    nixpkgs.url = "nixpkgs";  # flake registry: nixpkgs/nixpkgs-unstable

    /* alternatively,
      - use `master`, which is slightly more advanced;
      - pin to hash, e.g. "nixpkgs/a3a3dda3bacf61e8a39258a0ed9c924eeca8e293";
        ^ note that this is once problematic, but I cannot reproduce
        ^ find nice snapshots from hydra builds:
          https://hydra.nixos.org/jobset/nixpkgs/trunk/evals
    */

    nixpkgs_python2 = {
      /*
        - https://github.com/NixOS/nixpkgs/pull/201859 marks insecure
        - https://github.com/NixOS/nixpkgs/pull/245894 breaks build
        - https://github.com/NixOS/nixpkgs/pull/246976 fixes build
        - https://github.com/NixOS/nixpkgs/pull/246963 breaks again
        - https://github.com/NixOS/nixpkgs/pull/251548 fixes build

        pin to a working rev:
      */
      # url = "github:NixOS/nixpkgs/84892848d2622ba26279b8d959374dd5cbddc70d";
      follows = "nixpkgs";
      /*
        ^ alternatively, toggle to follow `nixpkgs`
      */
    };

    ## a nice filesystem based importer
    haumea = {
      url = "github:nix-community/haumea/v0.2.2";
      inputs.nixpkgs.follows = "nixpkgs";
      ## ^ only nixpkgs.lib is actually required
    };

  };

  outputs = { self, nixpkgs, haumea, ... } @ inputs:
  let

    importer = haumea.lib;
    lib = nixpkgs.lib // { inherit importer; };
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

    ## all overlays: the order matters!
    ## yet it's possible to cross ref through the `final` argument
    overlays = importer.load {
      src = ./overlays;
      loader = importer.loaders.verbatim;
    } // {
      inherit fromFlake;
      ## ^ defined below
    };

    ## overlay specific to this flake
    fromFlake = final: prev:
    { ## be careful of `rec`, might not work

      pkgsPython2 = import inputs.nixpkgs_python2 {
        inherit (prev) system config;
      };

      flakeInputs = final.collectFlakeInputs "nixpkgs-config" self;

      gimp = prev.gimp.override {
        withPython = true;
        python2 = final.pkgsPython2.python2;
      };

      ## exposes nixpkgs source, i.e. `outPath`, in `pkgs`
      inherit (nixpkgs) outPath;

      ## exposes importer
      inherit importer;

      ## helper function to gather overlaid packages, defined below
      gatherOverlaid = drvOverlays;

    };

    ## link farm all overlaid derivations
    drvOverlays = final: prev: let

      applied = builtins.mapAttrs (name: f: f final prev) overlays;
      merged = lib.attrsets.mergeAttrsList (builtins.attrValues applied);
      derivable = lib.filterAttrs (name: lib.isDerivation) merged;

      name = "user-drv-overlays";
    in {
      ${name} = prev.linkFarm name derivable;
    };

    legacyPackages = forMySystems (system: import nixpkgs {
      inherit system config;
      overlays = builtins.attrValues overlays ++ [ drvOverlays ];
    });

    packages = forMySystems (system: rec {
      inherit (legacyPackages.${system}) user-drv-overlays;
      default = user-drv-overlays;
    });

  in {

    inherit
      overlays
      legacyPackages
      packages;

    lib = lib.recursiveUpdate lib {
      systems.flakeExposed = mySystems;
      inherit
        mySystems
        forMySystems;
    };

  };
}
