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

    system-manager = {
      url = "github:numtide/system-manager";
      inputs.nixpkgs.follows = "nixpkgs-config/nixpkgs";
      ## ^ use the unmodified `nixpkgs`, to be imported
    };

  };

  outputs = { self, home-attrs, system-manager, ... }:
    let

      ## consistent namings
      nixpkgs-follows =
        let
          result = "nixpkgs-config";
          lock = builtins.fromJSON (builtins.readFile ./flake.lock);
        in
        assert lock.nodes.${result}.original.url == "file:./${result}";
        result;
      /* ^ refers to both the input _name_ & its _source_,
        .. therefore these two must coincide! */

      cheznix = self;
      nixpkgs = self.inputs.${nixpkgs-follows};
      inherit (nixpkgs) lib;

      ## upstream overrides: inputs.${nixpkgs-follows}
      ## home overlay:
      overlay = final: prev: import ./overlay.nix final prev // (with final; {
        inherit cheznix;
        inherit (system-manager.packages.${system}) system-manager;
      });

      machines = home-attrs.outputs;
      forMyMachines = f: lib.mapAttrs' f machines;
      inherit (lib)
        mySystems
        forMySystems;

      mkSystemPkgs = system: nixpkgs.legacyPackages.${system}.extend overlay;

      updateHomeAttrs = id: profile:
        profile // {
          hostname = profile.hostname or id;
          pkgs =
            assert lib.elem profile.system mySystems;
            mkSystemPkgs profile.system;
        };

      mkHomeConfig = id: profile:
        let
          attrs = updateHomeAttrs id profile;
          home-manager = attrs.pkgs.home-manager.flake;
        in
        {
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
        in
        {
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

    in
    {
      inherit lib;
      homeConfigurations = forMyMachines mkHomeConfig;
      systemConfigs = forMyMachines mkSystemConfig;
      legacyPackages = forMySystems mkSystemPkgs;
      packages = forMySystems (system: {
        default = self.legacyPackages.${system}.home-manager;
      });
      overlays.default = overlay;
    };
}
