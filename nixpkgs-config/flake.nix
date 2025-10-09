{
  description = "nixpkgs with personalized config";

  inputs = {

    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    # nixpkgs_python2 = {
    #   /*
    #     - https://github.com/NixOS/nixpkgs/pull/201859 marks insecure
    #     - https://github.com/NixOS/nixpkgs/pull/245894 breaks build
    #     - https://github.com/NixOS/nixpkgs/pull/246976 fixes build
    #     - https://github.com/NixOS/nixpkgs/pull/246963 breaks again
    #     - https://github.com/NixOS/nixpkgs/pull/251548 fixes build
    #
    #     pin to a working rev:
    #   */
    #   url = "github:NixOS/nixpkgs/8a33bfa212653a1f4d5f2c2d6097418bd639dda9";
    # };

    /** a nice filesystem based importer */
    haumea = {
      url = "github:nix-community/haumea/v0.2.2";
      inputs.nixpkgs.follows = "nixpkgs";
      ## ^ only nixpkgs.lib is actually required
    };

    /** a cool library for overrides */
    infuse = {
      url = "git+https://codeberg.org/amjoseph/infuse.nix.git";
      flake = false;
    };

    /** a nice type-checker for nix */
    yants = {
      url = "git+https://code.tvl.fyi/depot.git:/nix/yants.git";
      flake = false;
    };

    /** opengl support */
    nixgl = {
      url = "github:nix-community/nixGL";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-utils.follows = "flake-utils";
    };

    /** only used for nixgl */
    flake-utils.url = "github:numtide/flake-utils";

    flake-compat.url = "git+https://git.lix.systems/lix-project/flake-compat.git";

    determinate-nix-src = {
      url = "github:DeterminateSystems/nix-src/v3.11.2";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.nixpkgs-regression.follows = "nixpkgs";
      inputs.nixpkgs-23-11.follows = "nixpkgs";
      # work around https://github.com/NixOS/nix/issues/7807
      inputs.flake-parts.follows = "nixpkgs";
      inputs.git-hooks-nix.follows = "nixpkgs";
    };

  };

  outputs = { self, nixpkgs, haumea, infuse, nixgl, yants, flake-compat, determinate-nix-src, ... }:
  let

    lib = nixpkgs.lib.extend (final: prev: let lib = prev; in with final; {
      importer = haumea.lib;

      yants = import yants { inherit lib; };
      infusions = import infuse { inherit lib; };
      infuse = infusions.v1.infuse;

      flake-compat = let f = import flake-compat; in {
        __functor = self: f;
        getFlake = src: (f {
          inherit src;
          useBuiltinsFetchTree = builtins ? fetchTree;
        }).outputs;
        getFlakeImpure = src: (f {
          inherit src;
          useBuiltinsFetchTree = builtins ? fetchTree;
          copySourceTreeToStore = false;
        }).outputs;
      };

      mySystems = [ "x86_64-linux" "aarch64-darwin" ];
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
          with lib;
          false
          || (hasPrefix "python-2.7" name)
          || (hasPrefix "pulsar" name)
          || (hasPrefix "openssl-1.1.1w" name)
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

      nixgl = nixgl.overlays.default;

      ## overlay specific to this flake
      flake = final: prev @ { system, ... }: {

        flakeSelf = self;

        # pkgsPython2 = import inputs.nixpkgs_python2 {
        #   inherit (prev) system config;
        # };

        # gimp = prev.gimp.override {
        #   withPython = prev.stdenv.hostPlatform.isLinux;
        #   # python2 = final.pkgsPython2.python2;
        # };

        determinate-nix-oss = determinate-nix-src.packages.${system}.nix;

        ## nixpkgs source, i.e. `outPath`, in `pkgs`
        inherit (nixpkgs) outPath;

        ## overlays as an _attrset_, not a list
        attrOverlays = overlays;

        ## extended lib
        lib = prev.lib // lib;
      };
    };

    legacyPackages = lib.forMySystems (system:
    let
      nixpkgs-patched = nixpkgs.legacyPackages.${system}.callPackage ./patches {
        src = nixpkgs;
        inherit (lib) importer;
      };
    in import nixpkgs-patched {
      inherit system config;
      overlays = lib.attrValues overlays ++ [
        (_: { lib, ... }: {
          user-drv-overlays = lib.gatherOverlaid { };
          inherit nixpkgs-patched;
          inherit (nixpkgs-patched) trimPatch;
        })
      ];
    });

    packages = lib.forMySystems (system: rec {
      inherit (legacyPackages.${system}) user-drv-overlays nixpkgs-patched niz;
      default = user-drv-overlays;  # from `gatherOverlaid`
    });

    devShells = lib.forMySystems (system: rec {
      niz = (self.packages.${system}.niz.override {
        # prevent dependence on the source ./.; see ./niz/package.nix
        source = null;
      });
      default = niz;
    });

  in {

    inherit
      legacyPackages
      packages
      devShells
      lib
      overlays;

  };
}
