{
  description = "Home Manager configuration of bryan";

  inputs = {

    ## _private_ machine profiles:
    ## WARNING: _not_ secret, might leak through /nix/store & cache!
    home-attrs.url = "git+ssh://git@github.com/bryango/attrs.git";
    /*
      machines = home-attrs.outputs = {
        id = {
          ## machine's "profile"
          system = ... ;    ## required, for `nixpkgs.system`
          username = ... ;  ## required, for `home.username`
          homeDirectory = ... ;  ## optional, defaults to "/home/${username}"
          hostname = ... ;       ## optional, defaults to `id`
        };
      }
    */

    ## p13n nixpkgs with config
    nixpkgs-config.url = "git+file:./nixpkgs-config";

    home-manager = {
      url = "home-manager";  ## flake registry
      inputs.nixpkgs.follows = "nixpkgs-config";
    };

    system-manager = {
      url = "github:numtide/system-manager";
      inputs.nixpkgs.follows = "nixpkgs-config/nixpkgs";
        ## ^ use the unmodified `nixpkgs` to be imported
    };  ## this is cool but has a huge dependency tree!

    ## reference to last successful generation; manually bumped
    last-gen = {
      type = "git";
      url = "file:.";
      rev = "7161c2c7dbf6706ddc8141187a8851bf30a631ac";
      inputs.last-gen.follows = "last-gen";
      ## ^ beware of infinite recursion
    };
  };

  outputs = { self, home-manager, home-attrs, system-manager, ... }:
    let

      ## namings
      cheznix = self;
      nixpkgs-follows =
      let
        result = "nixpkgs-config";
        lock = builtins.fromJSON (builtins.readFile ./flake.lock);
      in
        assert lock.nodes.${result}.original.url == "file:./${result}";
        result;
      /* ^ refers to both the input _name_ & its _source_,
        .. therefore these two must coincide!
      */

      ## upstream overrides: inputs.${nixpkgs-follows}
      ## home overlay:
      overlay = final: prev: import ./overlay.nix final prev // {
        inherit cheznix;
        inherit (system-manager.packages.${prev.system}) system-manager;
      };

      nixpkgs = self.inputs.${nixpkgs-follows};
      lib = nixpkgs.lib // home-manager.lib;
      inherit (lib.chezlib) forMySystems;
      pkgsOverlay = system: nixpkgs.legacyPackages.${system}.extend overlay;

      machines = home-attrs.outputs;
      forMyMachines = f: lib.mapAttrs' f machines;

      updateHomeAttrs = id: profile:
        profile // {
          hostname = profile.hostname or id;
          pkgs = pkgsOverlay profile.system;
        };

      mkHomeConfig = id: profile:
        let
          attrs = updateHomeAttrs id profile;
        in {
          name = "${attrs.username}@${attrs.hostname}";
          value = home-manager.lib.homeManagerConfiguration {
            inherit (attrs) pkgs;

            ## specify your home configuration modules
            modules = [ ./home.nix ];

            ## pass through arguments to home.nix
            extraSpecialArgs = {
              inherit attrs cheznix nixpkgs-follows;
            };
          };
        };

      mkSystemConfig = id: profile:
        let
          attrs = updateHomeAttrs id profile;
        in {
          name = "${attrs.hostname}";
          value = system-manager.lib.makeSystemConfig {

            modules = [ ./system-modules ];
            extraSpecialArgs = {
              inherit attrs cheznix nixpkgs-follows;
              inherit (attrs) pkgs;
              ## ^ add overlaid nixpkgs
              ## ^ override github:numtide/system-manager/main/nix/lib.nix
            };
          };
        };

    in {
      inherit lib;
      inherit (home-manager) packages;
      homeConfigurations = forMyMachines mkHomeConfig;
      systemConfigs = forMyMachines mkSystemConfig;
      legacyPackages = forMySystems pkgsOverlay;
      overlays.default = overlay;
    };
}
