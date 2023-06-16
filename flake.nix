{
  description = "nixpkgs with personalized config";

  inputs = {

    nixpkgs.url = "nixpkgs";
    ## ... using flake registry
    ## ... hydra builds: https://hydra.nixos.org/jobset/nixpkgs/trunk/evals

    ## alternatively, use `unstable` which is slightly behind `master`
    # nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    # nixpkgs.url = "nixpkgs/a3a3dda3bacf61e8a39258a0ed9c924eeca8e293";

    ## python2 marked insecure: https://github.com/NixOS/nixpkgs/pull/201859
    ## ... pin to a successful build:
    nixpkgs_python2.url = "nixpkgs/7e63eed145566cca98158613f3700515b4009ce3";

    nixpkgs_biber217.url = "nixpkgs/40f79f003b6377bd2f4ed4027dde1f8f922995dd";
    ## ... from: https://hydra.nixos.org/build/202359527

  };

  outputs = { nixpkgs, ... } @ inputs:
  let

    system = "x86_64-linux";
    config = {
      ## https://github.com/nix-community/home-manager/issues/2954
      ## ... home-manager/issues/2942#issuecomment-1378627909
      allowBroken = true;
      allowUnfree = true;
    };

    pkgs_python2 = import inputs.nixpkgs_python2 {
      inherit system config;
    };

    pkgs_biber217 = import inputs.nixpkgs_biber217 {
      inherit system config;
    };

    pkgs = import nixpkgs {
      inherit system;
      config = {

        inherit (config) allowBroken allowUnfree;

        packageOverrides = pkgs: with pkgs; {

          ## specify user mods
          gimp-with-plugins = with pkgs_python2; gimp-with-plugins.override {
            plugins = with gimpPlugins; [ resynthesizer ];
          };
          gimp = with pkgs_python2; gimp.override {
            withPython = true;
          };

          tectonic = tectonic.override {
            biber = pkgs_biber217.biber;
          };
        };

        permittedInsecurePackages = [
          "python-2.7.18.6"
          "python-2.7.18.6-env"
        ];

      };
    };
  in {
    legacyPackages.${system} = pkgs;
  };
}
