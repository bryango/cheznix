{
  description = "system configurations of bryan";

  inputs = {

    /**
      _private_ machine attributes
      _not_ secret tho, might leak through /nix/store & cache!

      machines = home-attrs.outputs = {
        id = {
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
      isLinux = lib.hasSuffix "linux";
      isDarwin = lib.hasSuffix "darwin";
      linuxMachines = lib.filterAttrs (_: { system, ... }: isLinux system) machines;
      darwinMachines = lib.filterAttrs (_: { system, ... }: isDarwin system) machines;

      mergeAttrsListDeep = lib.foldl lib.recursiveUpdate { };
      forMyMachines = f: mergeAttrsListDeep (lib.mapAttrsToList f machines);
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

      mkSpecialAttrs = attrs: {
        inherit attrs cheznix nixpkgs-follows;
      };

      mkHomeConfig = id: {system, username, hostname, pkgs, ...}@attrs:
        let
          name = "${username}@${hostname}";
          value = attrs.pkgs.home-manager.flake.lib.homeManagerConfiguration {
            inherit (attrs) pkgs;

            ## specify your home configuration modules
            modules = [ ./home.nix ];

            ## pass through arguments to home.nix
            extraSpecialArgs = mkSpecialAttrs attrs;
          };
        in {
          ${name} = value;

          # some aliases
          ${system}.${name} = value;
          ${id} = value;
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
            modules = [
              ./darwin
              {
                nixpkgs = {
                  inherit (attrs) pkgs;
                };
              }
            ];
            specialArgs = {
              inherit attrs cheznix nixpkgs-follows;
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
        inherit (self.legacyPackages.${system}) home-manager;
        inherit (nix-darwin.packages.${system}) darwin-rebuild;
        default =
        # let
        #   pkgs = (mkSystemPkgs system);
        #   inherit (self.packages.${system})
        #     darwin-rebuild
        #     home-manager;
        # in pkgs.writeShellApplication {
        #   name = "build-config";
        #   runtimeInputs = [ pkgs.nix ];
        #   text = ''
        #       ${lib.optionalString (isDarwin system) ''

        #       ''}
        #   '';
        # };
          if isDarwin system
          then self.packages.${system}.darwin-rebuild
          else self.packages.${system}.home-manager;
      });
      overlays.default = overlay;

      # configurations by system for ci
      checkConfigurations = forMySystems (system:
        if isDarwin system
        then forMyDarwin mkDarwinConfig
        else forMyLinux mkHomeConfig
      );
    };
}
