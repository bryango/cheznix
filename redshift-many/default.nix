{ config, options, lib, pkgs, modulesPath, ... }:

let

  baseModuleName = "redshift-many";
  xdgConfigHome = config.xdg.configHome;
  opts = options.services.redshift;
  allInstances = config.services.${baseModuleName};

  instance = instanceName: instanceCfg: import ./instance.nix {
    inherit instanceName instanceCfg;
    inherit xdgConfigHome;
    inherit lib pkgs modulesPath;
  };

  instanceConfigGet = configAttrPath:
    instanceName: instanceCfg:
      lib.getAttrFromPath (["config"] ++ configAttrPath)
      (instance instanceName instanceCfg);

  mergeConfig = configAttrPath: with lib; mkMerge (
    mapAttrsToList (instanceConfigGet configAttrPath)
    allInstances
  );

  redshift-ctrl = pkgs.writeScriptBin "redshift-ctrl" (
    builtins.readFile (pkgs.substituteAll {
      src = ./redshift-ctrl.sh;
      allInstanceNames = with builtins; toString (attrNames allInstances);
    })
  );

in {

  config = {
    xdg.configFile = mergeConfig ["xdg" "configFile"];
    systemd = mergeConfig ["systemd"];
    home.packages = lib.mkMerge [
      ( mergeConfig ["home" "packages"] )
      [ redshift-ctrl ]
    ];
  };

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
