{ config, lib, pkgs, ... }:

let

  app = "v2ray";
  module = "${app}-ctrl";

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

  v2ray-ctrl = pkgs.binarySubstitute "vv" {
    src = ./vv.sh;
    inherit (cfg) outbounds routings;
  };

  v2config = pkgs.binarySubstitute "v2config" {
    src = ./v2config.py;
  };

in {

  options.programs.${module} = opts;

  config.home.packages = lib.mkIf cfg.enable (
    with pkgs; [
      v2ray
      v2ray-ctrl
      v2config
    ]
  );

}
