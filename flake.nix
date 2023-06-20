{
  description = "Home Manager configuration of bryan";

  inputs = {

    ## specify system attributes: for each system,
    ## ... provide attrsets with `system`, `username`, `homeDirectory`, ...
    ## ... WARNING: not secret, might leak through /nix/store & cache
    all-attrs.url = "git+ssh://git@github.com/bryango/attrs.git";

    ## specify the source of p13n nixpkgs with config
    nixpkgs.url = "github:bryango/nixpkgs-config";

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

      machines = all-attrs.outputs;

      forMyMachines = f: with builtins; listToAttrs (
        map f (attrNames machines)
      );

      mkHomeConfig = profile:
        let
          hostname = machines.${profile}.hostname or profile;
          system = machines.${profile}.system;
          pkgs = nixpkgs.legacyPackages.${system};
          attrs = machines.${profile} // {
            inherit hostname;
            inherit (pkgs) config;
          };
        in {
          name = "${attrs.username}@${hostname}";
          value = home-manager.lib.homeManagerConfiguration {
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
      homeConfigurations = forMyMachines mkHomeConfig;
      packages = home-manager.packages;
    };
}
