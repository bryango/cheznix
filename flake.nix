{
  description = "nixpkgs with personalized config";

  inputs = {

    nixpkgs.url = "nixpkgs";
    ## ... using flake registry
    ## ... hydra builds: https://hydra.nixos.org/jobset/nixpkgs/trunk/evals

    ## alternatively, use `unstable` which is slightly behind `master`
    # nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    # nixpkgs.url = "nixpkgs/a3a3dda3bacf61e8a39258a0ed9c924eeca8e293";
    ## ... WARNING: this doesn't seem to work properly!

    ## python2 marked insecure: https://github.com/NixOS/nixpkgs/pull/201859
    ## ... pin to a successful build:
    nixpkgs_python2.url = "github:NixOS/nixpkgs/7e63eed145566cca98158613f3700515b4009ce3";

    nixpkgs_biber217.url = "github:NixOS/nixpkgs/40f79f003b6377bd2f4ed4027dde1f8f922995dd";
    ## ... from: https://hydra.nixos.org/build/202359527

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

    generateOverrides = system:
    let

      pkgs_python2 = import inputs.nixpkgs_python2 {
        inherit system config;
      };

      pkgs_biber217 = import inputs.nixpkgs_biber217 {
        inherit system config;
      };

      collectFlakeInputs = name: flake: {
        ${name} = flake;
      } // lib.concatMapAttrs collectFlakeInputs (flake.inputs or {});
      ## https://github.com/NixOS/nix/issues/3995#issuecomment-1537108310

    in (pkgs: {

      inherit collectFlakeInputs;
      flakeInputs = collectFlakeInputs "nixpkgs-config" self;

      ## exec "$name" from system "$PATH"
      ## if not found, fall back to "$package/bin/$name"
      binaryFallback = name: package:
        pkgs.callPackage ./pkgs/binary-fallback {
          inherit name package;
        };

      ## create "bin/$name" from a template
      ## with `pkgs.substituteAll attrset`
      binarySubstitute = name: attrset: pkgs.writeScriptBin name (
        builtins.readFile (pkgs.substituteAll attrset)
      );

      ## some helper functions
      nixpkgs-helpers = {
        pkgs-lib = ./pkgs/nixpkgs-helpers/pkgs-lib.nix;
        pkgs-position = ./pkgs/nixpkgs-helpers/pkgs-position.nix;
      };  ## paths will get copied into store

      gimp = pkgs.gimp.override {
        withPython = true;
        python2 = pkgs_python2.python2;
      };

      tectonic-with-biber =
        pkgs.callPackage ./pkgs/tectonic-with-biber.nix {
          biber = pkgs_biber217.biber;
        };

      fcitx5-configtool =
        pkgs.libsForQt5.callPackage ./pkgs/fcitx5-configtool.nix {
          kcmSupport = false;
        };

      byobu-with-tmux = pkgs.callPackage (
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

      ## exposes nixpkgs source, i.e. `outPath`, in `pkgs`
      inherit (nixpkgs) outPath;

    });

  in {

    legacyPackages = forMySystems (system: import nixpkgs {

      inherit system;
      config = {

        inherit (config)
          allowBroken
          allowUnfree
          permittedInsecurePackages;

        packageOverrides = generateOverrides system;

      };
    });

    lib = lib.recursiveUpdate lib {
      systems.flakeExposed = mySystems;
    };

  };
}
