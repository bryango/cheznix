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
    nixpkgs-config.url = "path:./nixpkgs-config";

    nixpkgs.follows = "nixpkgs-config/nixpkgs";

    system-manager = {
      url = "github:numtide/system-manager";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-compat.follows = "nixpkgs-config/flake-compat";
        userborn.url = "github:jfroche/userborn/system-manager";
        userborn.inputs = {
          flake-compat.follows = "nixpkgs-config/flake-compat";
          systems.follows = "nixpkgs-config/flake-utils/systems";
        };
      };
    };

    nix-snapshotter = {
      url = "github:pdtpartners/nix-snapshotter";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-compat.follows = "nixpkgs-config/flake-compat";
        flake-parts.follows = "system-manager/userborn/flake-parts";
      };
    };

    nix-darwin = {
      url = "github:nix-darwin/nix-darwin/master";
      # /** https://github.com/nix-darwin/nix-darwin/pull/1635 */
      # url = "github:nix-darwin/nix-darwin?ref=pull/1635/merge";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    /** provide store path for some homemade darwin .apps */
    darwin-apps = {
      url = "git+https://gist.github.com/0057346dbf85981e58518be49d36fc06.git";
      flake = false;
    };

  };

  outputs = { self, home-attrs, system-manager, nix-darwin, home-manager, nix-snapshotter, ... }:
    let

      ## consistent namings
      nixpkgs-follows =
        let
          result = "nixpkgs-config";
          lock = builtins.fromJSON (builtins.readFile ./flake.lock);
        in
        assert lock.nodes.${result}.original.path == "./${result}";
        result;
      /* ^ refers to both the input _name_ & its _source_,
        .. therefore these two must coincide! */

      cheznix = self;
      nixpkgs = self.inputs.${nixpkgs-follows};
      inherit (nixpkgs) lib;
      # inherit (lib) yants;

      ## upstream overrides: inputs.${nixpkgs-follows}
      ## home overlay:
      overlay = final: prev: import ./overlay.nix final prev // (with final;
      let
        inherit (stdenv.hostPlatform) system;
      in
      {
        inherit cheznix;

        system-manager = system-manager.packages.${system}.default // {
          flake = system-manager;
          packages = system-manager.packages.${system};
        };

        home-manager = (home-manager.packages.${system}.home-manager.override ({ pkgs, ... }:  {
          ## option inspection does not work for flakes
          ## so simply drop this dependency to save space
          pkgs = pkgs // { nixos-option = null; };
        })) // {
          flake = home-manager;
          packages = home-manager.packages.${system};
        };

        darwin-rebuild = nix-darwin.packages.${system}.darwin-rebuild // {
          flake = nix-darwin;
          packages = nix-darwin.packages.${system};
        };

      } // ( nix-snapshotter.overlays.default final prev ));

      machines = lib.mapAttrs updateHomeAttrs home-attrs.outputs;
      isLinux = lib.hasSuffix "linux";
      isDarwin = lib.hasSuffix "darwin";
      linuxMachines = lib.filterAttrs (_: { system, ... }: isLinux system) machines;
      darwinMachines = lib.filterAttrs (_: { system, ... }: isDarwin system) machines;

      mkConfigWithAliases = id: { system, ... }@_attrs: { name, value }: {
        ${name} = value;
        ${system}.${id} = value; # .${system} alias
      } // {
        ${id} = value; # unique id
      };

      /** lib.mergeAttrsList, but with deep merges */
      mergeAttrsListDeep = lib.foldl lib.recursiveUpdate { };
      genMergedAttrs = x: f: mergeAttrsListDeep (lib.mapAttrsToList f x);

      forMyMachines = genMergedAttrs machines;
      forMyLinux = genMergedAttrs linuxMachines;
      forMyDarwin = genMergedAttrs darwinMachines;
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

      mkHomeConfig = id: { system, username, hostname, pkgs, ... }@attrs:
        mkConfigWithAliases id attrs {
          name = "${username}@${hostname}";
          value = home-manager.lib.homeManagerConfiguration {
            inherit pkgs;

            ## specify your home configuration modules
            modules = [
              ./home.nix
              {
                # must set for `nix.settings` and stuff
                nix.package = pkgs.nixPackage; # defined in `nixpkgs-config`
              }
              (lib.optionalAttrs (hostname == "btrsamsung") {
                imports = [ nix-snapshotter.homeModules.default ];
                virtualisation.containerd.rootless = {
                  enable = true;
                  nixSnapshotterIntegration = true;
                  path = [
                    "/usr"
                  ];
                };
                services.nix-snapshotter.rootless = {
                  enable = true;
                };
                home.packages = [ pkgs.nerdctl ];
              })
            ];

            ## pass through arguments to home.nix
            extraSpecialArgs = mkSpecialAttrs attrs;
          };
        };

      mkSystemConfig = id: { pkgs, ... }@attrs:
        mkConfigWithAliases id attrs {
          name = "${attrs.hostname}";
          value = system-manager.lib.makeSystemConfig {

            modules = [
              ./system-modules
              {
                networking.hostName = attrs.hostname;
                nix.package = pkgs.nixPackage; # defined in `nixpkgs-config`
                system.nixos.flake.source = self;
              }
            ];
            specialArgs = mkSpecialAttrs attrs // {
              inherit pkgs;
              ## ^ add overlaid nixpkgs
              ## ^ override github:numtide/system-manager/main/nix/lib.nix
            };
          };
        };

      mkDarwinConfig = id: { hostname, pkgs, ... }@attrs:
        mkConfigWithAliases id attrs {
          name = "${hostname}";
          value = nix-darwin.lib.darwinSystem {
            modules = [
              ./darwin
              {
                nixpkgs = {
                  inherit pkgs;
                };
                nix.package = pkgs.nixPackage; # defined in `nixpkgs-config`
              }
            ];
            specialArgs = mkSpecialAttrs attrs;
          };
        };

    in
    {
      inherit lib;
      overlays.default = overlay;
      homeConfigurations = forMyMachines mkHomeConfig;
      systemConfigs = forMyLinux mkSystemConfig;
      darwinConfigurations = forMyDarwin mkDarwinConfig;
      legacyPackages = forMySystems mkSystemPkgs;
      packages = forMySystems (system:
      let
        pkgs = self.legacyPackages.${system};

        darwinConfigs = self.darwinConfigurations.${system} or { };
        homeConfigs = self.homeConfigurations.${system} or { };
        mkConfigNames = configs: lib.pipe configs [
          lib.attrNames
          lib.escapeShellArgs
        ];
        darwinConfigNames = mkConfigNames darwinConfigs;
        homeConfigNames = mkConfigNames homeConfigs;

        packages =
        lib.optionalAttrs ((nix-darwin.packages.${system}.darwin-rebuild or {}) != {})
          {
            inherit (pkgs) darwin-rebuild;
          }
        // lib.optionalAttrs ((home-manager.packages.${system}.home-manager or {}) != {})
          {
            inherit (pkgs) home-manager;
          };
      in packages // {
        config-manager = pkgs.writeShellApplication rec {
          name = "config-manager";
          runtimeInputs = lib.attrValues packages;
          excludeShellChecks = [
            "SC2043" # allow for loops to run only once
          ];
          text = ''
            >&2 echo ${name}: applying [ "$@" ] to all supported configurations:
            >&2 echo
            >&2 echo "   - darwinConfigurations: [ ${darwinConfigNames} ] "
            >&2 echo "   - homeConfigurations: [ ${homeConfigNames} ] "
            >&2 echo
            >&2 echo ${name}: starting in 3 seconds ...
            >&2 echo
            sleep 3
            set -x
            for oneConfig in ${darwinConfigNames}; do
              darwin-rebuild --flake ".#$oneConfig" "$@"
            done
            for oneConfig in ${homeConfigNames}; do
              home-manager --flake .#$oneConfig "$@"
            done
            set +x
          '';
        };
        default =
        let
          mapConfigs = configs: prefix: (lib.mapAttrs' (name: value: {
            name = "${prefix}-${name}";
            value = value.activationPackage /* hm */ or value.system /* darwin */;
          }) configs);
          homePackages = mapConfigs homeConfigs "home";
          darwinPackages = mapConfigs darwinConfigs "darwin";
          allPackages = darwinPackages // homePackages;
        in pkgs.linkFarm "activation-packages" allPackages;
      });
      apps = forMySystems (system: {
        default = {
          type = "app";
          program = lib.getExe self.packages.${system}.config-manager;
        };
      });
    };
}
