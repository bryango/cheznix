/** Check for Codex reset credits expiring within 48 hours. */

{ lib, pkgs, ... }:

let
  checkCredits = pkgs.writeShellScriptBin "codex-reset-credit-expiry" ''
    exec ${lib.getExe pkgs.python3} -u ${./check.py} "$@"
  '';
in {
  config = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
    home.packages = [ checkCredits ];

    launchd.agents.codex-reset-credit-expiry = {
      enable = true;
      config = {
        ProgramArguments = [ "${checkCredits}/bin/codex-reset-credit-expiry" ];
        ProcessType = "Background";
        RunAtLoad = true;
        StartInterval = 21600;
      };
    };
  };
}
