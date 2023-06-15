{
  description = "Home Manager configuration of bryan";

  inputs = {

    ## specify system attributes: for each system,
    ## ... provide attrsets with `system`, `username`, `homeDirectory`, ...
    ## ... WARNING: not secret, might leak through /nix/store & cache
    all-attrs.url = "git+ssh://git@github.com/bryango/attrs.git";

    ## specify the source of home-manager and nixpkgs
    ## ... using flake registry:
    nixpkgs.url = "nixpkgs";

    ## alternatively,
    # nixpkgs.url = "nixpkgs/a3a3dda3bacf61e8a39258a0ed9c924eeca8e293";
    # nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    ## ... `unstable` lags a little bit behind `master`

    home-manager = {
      url = "home-manager";
      # url = "github:nix-community/home-manager";

      ## home-manager is also a flake
      ## ... but we ask it to follow our nixpkgs:
      inputs.nixpkgs.follows = "nixpkgs";
    };

  };

  outputs = { nixpkgs, home-manager, all-attrs, ... }:
    let
      mkMachineConfig = hostname:
        let
          attrs = all-attrs.${hostname} // {
            config = {
              ## https://github.com/nix-community/home-manager/issues/2954
              ## ... home-manager/issues/2942#issuecomment-1378627909
              allowBroken = true;
              allowUnfree = true;
            };
          };
          pkgs = import nixpkgs {
            inherit (attrs) system config;
          };
        in {
          homeConfigurations."${attrs.username}@${hostname}" =
          home-manager.lib.homeManagerConfiguration {
            inherit pkgs;

            # Specify your home configuration modules here, for example,
            # the path to your home.nix.
            modules = [ ./home.nix ];

            # Optionally use extraSpecialArgs
            # to pass through arguments to home.nix
            extraSpecialArgs = {
              inherit attrs;
            };
          };
        };
    in {
      inherit (mkMachineConfig "btrsamsung") homeConfigurations;
    };
}
