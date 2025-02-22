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

  redshift-ctrl = pkgs.binarySubstitute "redshift-ctrl" {
    src = ./redshift-ctrl.sh;
    allInstanceNames = toString (lib.attrNames allInstances);
  };

  xrandr = pkgs.xorg.xrandr;

  xrandr-brightness = pkgs.binarySubstitute "xrandr-brightness" {
    src = ./xrandr-brightness.sh;
    device = config.programs.xrandr-brightness.output;
    ## ... `output` is a internal nix keyword
  };

in {

  config = lib.mkIf pkgs.hostPlatform.isLinux {
    xdg.configFile = mergeConfig ["xdg" "configFile"];
    systemd = mergeConfig ["systemd"];
    home.packages = lib.mkMerge [
      ( mergeConfig ["home" "packages"] )
      [ ## more control scripts & packages
        redshift-ctrl
        xrandr
        xrandr-brightness
      ]
    ];
  };

  options.programs.xrandr-brightness = {
    output = with lib; mkOption {
      type = types.str;
      default = "HDMI-1";
      description = ''
        Set the default `--output` device for `xrandr-brightness`.
        Can be overriden at runtime with env `XRANDR_OUTPUT`.
      '';
    };
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
