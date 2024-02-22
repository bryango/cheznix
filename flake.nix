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

    # nixpkgs_python2 = {
    #   /*
    #     - https://github.com/NixOS/nixpkgs/pull/201859 marks insecure
    #     - https://github.com/NixOS/nixpkgs/pull/245894 breaks build
    #     - https://github.com/NixOS/nixpkgs/pull/246976 fixes build
    #     - https://github.com/NixOS/nixpkgs/pull/246963 breaks again
    #     - https://github.com/NixOS/nixpkgs/pull/251548 fixes build

    #     pin to a working rev:
    #   */
    #   url = "github:NixOS/nixpkgs/8a33bfa212653a1f4d5f2c2d6097418bd639dda9";
    # };

    ## a nice filesystem based importer
    haumea = {
      url = "github:nix-community/haumea/v0.2.2";
      inputs.nixpkgs.follows = "nixpkgs";
      ## ^ only nixpkgs.lib is actually required
    };

  };

  outputs = { self, nixpkgs, haumea, ... }:
  let

    lib = nixpkgs.lib.extend (final: prev: let lib = prev; in with final; {
      importer = haumea.lib;
      mySystems = [ "x86_64-linux" ];
      forMySystems = lib.genAttrs mySystems;
    });

    config = {
      ## https://github.com/nix-community/home-manager/issues/2954
      ## ... home-manager/issues/2942#issuecomment-1378627909
      allowBroken = true;
      allowUnfree = true;

      ## nixpkgs: pkgs/stdenv/generic/check-meta.nix
      allowInsecurePredicate = pkg:
        let
          name = pkg.name or "${pkg.pname or "«name-missing»"}-${pkg.version or "«version-missing»"}";
        in
          false
          || (lib.hasPrefix "python-2.7" name)
          || (lib.hasPrefix "pulsar" name)
        ;
    };

    ## _attrset_ of flake-style named overlays
    overlays = lib.importer.load {
      /*
        The order of overlays _does_ matter but is obscured here!
        To cross ref reliably, use the `final` argument
      */
      src = ./overlays;
      loader = lib.importer.loaders.verbatim;
    } // {
      ## overlay specific to this flake
      flake = final: prev: {

        flakeSelf = self;

        # pkgsPython2 = import inputs.nixpkgs_python2 {
        #   inherit (prev) system config;
        # };

        gimp = prev.gimp.override {
          withPython = true;
          # python2 = final.pkgsPython2.python2;
        };

        ## nixpkgs source, i.e. `outPath`, in `pkgs`
        inherit (nixpkgs) outPath;

        ## overlays as an _attrset_, not a list
        attrOverlays = overlays;

        ## extended lib
        lib = prev.lib // lib;
      };
    };


    legacyPackages = lib.forMySystems (system: import nixpkgs {
      inherit system config;
      overlays = lib.attrValues overlays ++ [
        (_: { lib, ... }: { user-drv-overlays = lib.gatherOverlaid { }; })
      ];
    });

    packages = lib.forMySystems (system: rec {
      inherit (legacyPackages.${system}) user-drv-overlays;
      default = user-drv-overlays;  # from `gatherOverlaid`
    });

  in {

    inherit
      legacyPackages
      packages
      lib
      overlays;

  };
}
