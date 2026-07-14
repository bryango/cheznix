/** launchd agent to disable codex auto update */

{ config, lib, pkgs, ... }:

let
  enforceCodexAutoUpdate = pkgs.writeShellScript "codex-disable-auto-update" ''
    set -eu

    domain="com.openai.codex"
    key="SUAutomaticallyUpdate"

    current=$(/usr/bin/defaults read "$domain" "$key" 2>/dev/null || true)

    if [ "$current" != "0" ]; then
      /usr/bin/defaults write "$domain" "$key" -bool false
    fi
  '';
in {
  config = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
    launchd.agents.codex-disable-auto-update = {
      enable = true;
      config = {
        ProgramArguments = [ "${enforceCodexAutoUpdate}" ];
        ProcessType = "Background";
        RunAtLoad = true;
        ThrottleInterval = 1;
        WatchPaths = [
          "${config.home.homeDirectory}/Library/Preferences/com.openai.codex.plist"
        ];
      };
    };
  };
}
