{ config, lib, pkgs, ... }:

let

  app = "v2ray";
  module = "${app}-ctrl";
  script = "vv";

  opts = {
    enable = lib.mkEnableOption module // {
      default = true;
    };

    outbounds = with lib; mkOption {
      type = types.str;
      example = "dal6-la4";
      description = ''
        Set the outbound servers for ${app}, chained with `-`.
        Available outbounds defined in `~/apps/v2ray/config/outbounds`
      '';
    };

    routings = with lib; mkOption {
      type = types.str;
      default =
        "private-direct,cn-direct,tencent-direct,ms-transit,zoom-transit";
      description = ''
        Set the routing profiles for ${app}, seperated with `,`.
        Available routings defined in `~/apps/v2ray/config/routings`
      '';
    };

  };

  cfg = config.programs.${module};

  v2ray-ctrl = pkgs.writeScriptBin script (
    builtins.readFile (pkgs.substituteAll {
      src = ./. + "/${script}.sh";
      inherit (cfg) outbounds routings;
      # allInstanceNames = with builtins; toString (attrNames allInstances);
    })
  );

in {

  options.programs.${module} = opts;

  config.home.packages = lib.mkIf cfg.enable (
    with pkgs; [
      v2ray
      v2ray-ctrl
    ]
  );

}
