{
  description = "Home Manager configuration of bryan";

  inputs = {

    /**
      _private_ machine profiles
      _not_ secret, might leak through /nix/store & cache!

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
    home-attrs.url = "git+ssh://git@github.com/bryango/attrs.git";
    /* cachix update:
        nix eval --raw cheznix#cheznix.inputs.home-attrs.outPath \
        | cachix push chezbryan
    */

    ## p13n nixpkgs with config
    nixpkgs-config.url = "git+file:./nixpkgs-config";

    system-manager = {
      url = "github:numtide/system-manager";
      inputs.nixpkgs.follows = "nixpkgs-config/nixpkgs";
    };

    nix-darwin = {
      url = "github:LnL7/nix-darwin/master";
      inputs.nixpkgs.follows = "nixpkgs-config/nixpkgs";
    };
  };

  outputs = { self, home-attrs, system-manager, nix-darwin, ... }:
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

      machines = lib.mapAttrs updateHomeAttrs home-attrs.outputs;
      isLinux = { system, ... }: lib.hasSuffix system "linux";
      isDarwin = { system, ... }: lib.hasSuffix system "darwin";
      linuxMachines = lib.filterAttrs (_: isLinux) machines;
      darwinMachines = lib.filterAttrs (_: isDarwin) machines;

      forMyMachines = f: lib.mapAttrs' f machines;
      forMyLinux = f: lib.mapAttrs' f linuxMachines;
      forMyDarwin = f: lib.mapAttrs' f darwinMachines;
      inherit (lib)
        mySystems
        forMySystems;

      mkSystemPkgs = system: nixpkgs.legacyPackages.${system}.extend overlay;

      updateHomeAttrs = id: attrs:
        attrs // {
          hostname = attrs.hostname or id;
          pkgs =
            assert lib.elem attrs.system mySystems;
            mkSystemPkgs attrs.system;
        };

      mkHomeConfig = id: attrs:
        {
          name = "${attrs.username}@${attrs.hostname}";
          value = attrs.pkgs.home-manager.flake.lib.homeManagerConfiguration {
            inherit (attrs) pkgs;

            ## specify your home configuration modules
            modules = [ ./home.nix ];

            ## pass through arguments to home.nix
            extraSpecialArgs = {
              inherit attrs cheznix nixpkgs-follows;
            };
          };
        };

      mkSystemConfig = id: attrs:
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

      mkDarwinConfig = id: attrs:
        {
          name = "${attrs.hostname}";
          value = nix-darwin.lib.darwinSystem {

            modules = [ ./darwin ];
            specialArgs = {
              inherit attrs cheznix nixpkgs-follows;
              # inherit (attrs) pkgs;
              # ## ^ add overlaid nixpkgs (not sure if supported)
            };
          };
        };

    in
    {
      inherit lib;
      homeConfigurations = forMyMachines mkHomeConfig;
      systemConfigs = forMyLinux mkSystemConfig;
      darwinConfigurations = forMyDarwin mkDarwinConfig;
      legacyPackages = forMySystems mkSystemPkgs;
      packages = forMySystems (system: {
        default = self.legacyPackages.${system}.home-manager;
        inherit (self.nix-darwin.${system}) darwin-rebuild;
      });
      overlays.default = overlay;
    };
}
