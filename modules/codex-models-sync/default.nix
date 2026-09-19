/** Keep the Codex v1 model catalog synchronized. */

{ lib, pkgs, ... }:

let
  syncModels = pkgs.writeShellScriptBin "codex-models-sync" ''
    exec ${lib.getExe pkgs.python3} ${./sync.py} "$@"
  '';
in {
  config = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
    home.packages = [ syncModels ];

    launchd.agents.codex-models-sync = {
      enable = true;
      config = {
        ProgramArguments = [ "${syncModels}/bin/codex-models-sync" ];
        ProcessType = "Background";
        RunAtLoad = true;
        StartInterval = 28800;
      };
    };
  };
}
