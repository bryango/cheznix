{ config, lib, ... }:

let

  category = "programs";
  module = "direnv-exec-apps";

  opts = {
    enable = lib.mkEnableOption module // {
      default = true;
    };

    apps = with lib; mkOption {
      example = [ "pdflatex" ];
      description = ''
        List of app binary names to wrap with `direnv exec .`.
      '';
      type = types.listOf types.str;
    };
  };

  cfg = config.${category}.${module};

in {

  options.${category}.${module} = opts;

  config.home.file = lib.mkIf cfg.enable (lib.genAttrs cfg.apps (appName: {
    executable = true;
    source = ./direnv-exec-wrapper.sh;
    target = "bin/${appName}";
  }));

}
