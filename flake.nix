{
  description = "nixpkgs with personalized config";

  inputs = {

    nixpkgs.url = "nixpkgs";  ## ... using flake registry:

    ## alternatively,
    # nixpkgs.url = "nixpkgs/a3a3dda3bacf61e8a39258a0ed9c924eeca8e293";
    # nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    ## ... `unstable` lags a little bit behind `master`

  };

  outputs = { nixpkgs, ... }:
  let

    ## python2 marked insecure: https://github.com/NixOS/nixpkgs/pull/201859
    ## ... last hydra build before that:
    ##     https://hydra.nixos.org/eval/1788908?filter=python2&full=#tabs-inputs
    ## ... obtained by inspecting:
    ##     https://hydra.nixos.org/jobset/nixpkgs/trunk/evals
    nixpkgs_python2 = import (builtins.fetchTarball {
      url = "https://github.com/NixOS/nixpkgs/archive/7e63eed145566cca98158613f3700515b4009ce3.tar.gz";
      sha256 = "1yazcc1hng3pbvml1s7i2igf3a90q8v8g6fygaw70vis32xibhz9";
      ## ... generated from `nix-prefetch-url --unpack`
    }) {};

    nixpkgs_biber217 = import (builtins.fetchTarball {
      ## from: https://hydra.nixos.org/build/202359527
      url = "https://github.com/NixOS/nixpkgs/archive/40f79f003b6377bd2f4ed4027dde1f8f922995dd.tar.gz";
      sha256 = "1javsbaxf04fjygyp5b9c9hb9dkh5gb4m4h9gf9gvqlanlnms4n5";
    }) {};

  in import nixpkgs {
      config = {
        ## https://github.com/nix-community/home-manager/issues/2954
        ## ... home-manager/issues/2942#issuecomment-1378627909
        allowBroken = true;
        allowUnfree = true;

        packageOverrides = pkgs: with pkgs; {

          ## specify user mods
          gimp-with-plugins = with pkgs; gimp-with-plugins.override {
            plugins = with gimpPlugins; [ resynthesizer ];
          };
          gimp = with pkgs; gimp.override {
            withPython = true;
          };

          tectonic = tectonic.override {
            biber = nixpkgs_biber217.biber;
          };
        };

        permittedInsecurePackages = [
          "python-2.7.18.6"
          "python-2.7.18.6-env"
        ];

      };
    };
}
