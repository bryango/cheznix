{
  description = "Home Manager configuration of bryan";

  inputs = {

    ## _private_ machine profiles:
    ## WARNING: _not_ secret, might leak through /nix/store & cache!
    home-attrs.url = "git+ssh://git@github.com/bryango/attrs.git";
    /*
      machines = home-attrs.outputs = {
        id = {
          system = ... ;
          username = ... ;
          homeDirectory = ... ;
        };
      }
    */

    nixpkgs.url = "nixpkgs";  ## flake registry

    ## p13n nixpkgs with config
    nixpkgs-config = {
      url = "git+file:./nixpkgs-config";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "home-manager";  ## flake registry
      inputs.nixpkgs.follows = "nixpkgs-config";
    };

  };

  outputs = { self, home-manager, home-attrs, ... }:
    let

      ## namings
      cheznix = self;
      nixpkgs-follows = "nixpkgs-config";
      /* ^ refers to both the input NAME & its SOURCE directory,
        .. therefore these two must coincide!

          assert inputs.${nixpkgs-follows}.url    ## pseudo code
              == "git+file:./${nixpkgs-follows}"  ## doesn't work

        It is very hard to ensure this programmatically,
        .. due to the pure nature of flakes.
      */

      ## upstream overrides: inputs.${nixpkgs-follows}
      ## home overlay:
      overlay = final: prev: {

        gimp-with-plugins = with prev; gimp-with-plugins.override {
          plugins = with gimpPlugins; [ resynthesizer ];
        };

        redshift = prev.redshift.override {
          withGeolocation = false;
        };

        fzf = prev.fzf.override {
          glibcLocales = "/usr";
        };

      };

      nixpkgs = self.inputs.${nixpkgs-follows};
      inherit (nixpkgs) lib;
      inherit (lib) forMySystems;
      pkgsOverlay = system: nixpkgs.legacyPackages.${system}.extend overlay;
      libOverlay = system: (pkgsOverlay system).lib;

      machines = home-attrs.outputs;
      forMyMachines = f: lib.mapAttrs' f machines;
      mkHomeConfig = id: profile:
        let
          hostname = profile.hostname or id;
          pkgs = pkgsOverlay profile.system;
          attrs = profile // {
            inherit hostname;
            inherit (pkgs) config overlays;
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
              inherit attrs cheznix nixpkgs-follows;
            };
          };
        };
    in {
      packages = home-manager.packages;
      homeConfigurations = forMyMachines mkHomeConfig;
      legacyPackages = forMySystems pkgsOverlay;
      lib = forMySystems libOverlay;
      overlays.default = overlay;
    };
}
