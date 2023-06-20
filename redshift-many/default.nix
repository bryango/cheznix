{ config, options, lib, pkgs, modulesPath, ... }:

let

  baseModuleName = "redshift-many";
  xdgConfigHome = config.xdg.configHome;
  cfg = config.services.${baseModuleName};
  opts = options.services.redshift;

  instance = { instanceName, instanceCfg }: import ./instance.nix {
    inherit instanceName instanceCfg;
    inherit xdgConfigHome;
    inherit lib pkgs modulesPath;
  };

in {

  config = with lib; mkMerge (
    mapAttrsToList (
      instanceName: instanceCfg:
        let
          inherit (instance { inherit instanceName instanceCfg; }) config;
        in {
          inherit (config) systemd;
          inherit (config.xdg) configFile;
          inherit (config.home) packages;
        }
    ) cfg
  );

  options.services.${baseModuleName} = with lib; mkOption {
    default = { };
    example = literalExpression ''
      {
        internal = {
          temperature.always = 3200;
          settings.randr.crtc = 0;
        };
      };
    '';
    type = with types; attrsOf (submodule {

      ## inheriting redshift options
      options = recursiveUpdate opts {

        ## extending options
        temperature.always = mkOption {
          type = types.nullOr types.int;
          default = null;
          description = ''
            Colour temperature to use for day _and_ night, between
            <literal>1000</literal> and <literal>25000</literal> K.
          '';
        };
      };

    });
    description = ''
      The configuration for many redshift instances.
    '';
  };

}
