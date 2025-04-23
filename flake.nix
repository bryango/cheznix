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

    /** provide store path for some homemade darwin .apps */
    darwin-apps = {
      url = "git+https://gist.github.com/0057346dbf85981e58518be49d36fc06.git";
      flake = false;
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
      # inherit (lib) yants;

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
          value = pkgs.home-manager.flake.lib.homeManagerConfiguration {
            inherit pkgs;

            ## specify your home configuration modules
            modules = [ ./home.nix ];

            ## pass through arguments to home.nix
            extraSpecialArgs = mkSpecialAttrs attrs;
          };
        };

      mkSystemConfig = id: { pkgs, ... }@attrs:
        mkConfigWithAliases id attrs {
          name = "${attrs.hostname}";
          value = system-manager.lib.makeSystemConfig {

            modules = [ ./system-modules ];
            extraSpecialArgs = mkSpecialAttrs attrs // {
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
        nixDarwinPackages = nix-darwin.packages.${system};

        packages =
        lib.optionalAttrs (nixDarwinPackages ? darwin-rebuild)
          {
            darwin-rebuild = nixDarwinPackages.darwin-rebuild // {
              flake = nix-darwin;
              packages = nixDarwinPackages;
            };
          }
        // rec {
            home-manager = pkgs.home-manager // {
              packages = home-manager.flake.packages.${system};
            };
          };
      in packages // {
        default =
        let
          mkConfigNames = configs: lib.pipe configs [
            (x: x.${system} or { })
            lib.attrNames
            lib.escapeShellArgs
          ];
          darwinConfigNames = mkConfigNames self.darwinConfigurations;
          homeConfigNames = mkConfigNames self.homeConfigurations;

        in pkgs.writeShellApplication rec {
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
      });
    };
}
