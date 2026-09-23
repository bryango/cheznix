/** Run a locally built personal dashboard checkout. */

{ config, lib, pkgs, ... }:

let

  module = "personal-dashboard";
  cfg = config.services.${module};
  inherit (pkgs.stdenv.hostPlatform) isDarwin isLinux;

  opts = with lib; {
    enable = mkEnableOption module;

    directory = mkOption {
      type = types.str;
      description = "Absolute path to the dashboard checkout, including dist and node_modules.";
    };

    configFile = mkOption {
      type = types.str;
      default = "${cfg.directory}/config.local.json";
      description = "Runtime JSON configuration path; its contents are not copied into the Nix store.";
    };

    dataDirectory = mkOption {
      type = types.str;
      default = "${cfg.directory}/.dashboard-data";
      description = "Shared server and CLI database directory.";
    };

    nodePackage = mkOption {
      type = types.package;
      default = pkgs.nodejs-slim_latest;
      description = "Node.js runtime with node:sqlite support (at least 24.19).";
    };
  };

  command = name: entry: pkgs.writeShellScriptBin name ''
    set -eu
    export DASHBOARD_CONFIG=${lib.escapeShellArg cfg.configFile}
    export DATA_DIRECTORY=${lib.escapeShellArg cfg.dataDirectory}
    ${lib.optionalString isLinux ''
      export PATH=${lib.makeBinPath [ pkgs.iproute2 ]}:"$PATH"
    ''}
    cd ${lib.escapeShellArg cfg.directory}
    exec ${lib.getExe cfg.nodePackage} ${lib.escapeShellArg "${cfg.directory}/dist/server/${entry}.js"} "$@"
  '';

  server = command module "main";
  cli = command "dashboard" "cli";

in {

  options.services.${module} = opts;

  config = lib.mkIf cfg.enable {
    assertions = [ {
      assertion = lib.all (path: lib.hasPrefix "/" path) [
        cfg.directory cfg.configFile cfg.dataDirectory
      ];
      message = "personal-dashboard requires absolute runtime paths.";
    } ];

    home.packages = [ server cli ];

    launchd.agents.${module} = lib.mkIf isDarwin {
      enable = true;
      config = {
        ProgramArguments = [ "${server}/bin/${module}" ];
        WorkingDirectory = cfg.directory;
        ProcessType = "Background";
        RunAtLoad = true;
        KeepAlive = true;
        ThrottleInterval = 10;
      };
    };

    systemd.user.services.${module} = lib.mkIf isLinux {
      Unit.Description = "Personal dashboard";
      Service = {
        ExecStart = "${server}/bin/${module}";
        WorkingDirectory = cfg.directory;
        Restart = "on-failure";
        RestartSec = 10;
        UMask = "0077";
      };
      Install.WantedBy = [ "default.target" ];
    };
  };

}
