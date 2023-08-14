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
        - pin to its parent commit:
      */
      # url = "github:NixOS/nixpkgs/020ff5ccb510f0eb1810a42bfa0f8fcd68ba4822";
      follows = "nixpkgs";
      /*
        ^ alternatively, toggle to follow `nixpkgs`
      */
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

    ## all overlays: the order matters!
    ## yet it's possible to cross ref through the `final` argument
    overlays = {
      utils = import ./overlays/utils.nix;
      mods = import ./overlays/mods.nix;

      inherit fromFlake;
      ## ^ defined below
    };

    ## overlay specific to this flake
    fromFlake = final: prev:
    let

      pkgs_python2 = import inputs.nixpkgs_python2 {
        inherit (prev) system config;
      };

    in { ## be careful of `rec`, might not work

      flakeInputs = prev.collectFlakeInputs "nixpkgs-config" self;

      gimp = prev.gimp.override {
        withPython = true;
        python2 = pkgs_python2.python2;
      };

      ## exposes nixpkgs source, i.e. `outPath`, in `pkgs`
      inherit (nixpkgs) outPath;

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

  in {

    inherit overlays;

    legacyPackages = forMySystems (system: import nixpkgs {
      inherit system config;
      overlays = builtins.attrValues overlays ++ [ drvOverlays ];
    });

    lib = lib.recursiveUpdate lib {
      systems.flakeExposed = mySystems;
      inherit
        mySystems
        forMySystems;
    };

  };
}
