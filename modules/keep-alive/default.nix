/** Keep bundled macOS apps running through one LaunchAgent per app.

    macOS refuses to execute a protected app bundle directly: the kernel kills
    the process at startup with `SIGKILL (Code Signature Invalid)` and reports a
    launch-constraint violation in the crash log. Each agent therefore asks
    LaunchServices to open the app, and reopens it whenever it disappears.
*/

{ config, lib, pkgs, ... }:

let

  module = "keep-alive";
  cfg = config.services.${module};

  inherit (pkgs.stdenv.hostPlatform) isDarwin;

  agentName = name: "${module}.${name}";
  agentLabel = name: "org.nix-community.home.${agentName name}";
  launchAgentsDir = "${config.home.homeDirectory}/Library/LaunchAgents";

  appType = lib.types.submodule {
    options = {
      path = lib.mkOption {
        type = lib.types.str;
        example = "/System/Applications/Mail.app";
        description = "Absolute path to an app bundle.";
      };

      args = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Arguments handed to the app through `open --args`.";
      };

      environmentVariables = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        default = { };
        description = "Environment variables set for the LaunchAgent.";
      };

      restart = lib.mkOption {
        type = lib.types.enum [ "always" "onLogin" ];
        default = cfg.restart;
        description = "Override the module-wide `restart` policy.";
      };

      pollInterval = lib.mkOption {
        type = lib.types.ints.positive;
        default = cfg.pollInterval;
        description = "Override the module-wide liveness poll, in seconds.";
      };

      throttleInterval = lib.mkOption {
        type = lib.types.ints.positive;
        default = cfg.throttleInterval;
        description = "Override the module-wide restart throttle, in seconds.";
      };
    };
  };

  apps = lib.mapAttrs
    (_: value: if lib.isString value then { path = value; } else value)
    cfg.apps;

  restartFor = app: app.restart or cfg.restart;
  pollFor = app: toString (app.pollInterval or cfg.pollInterval);
  throttleFor = app: app.throttleInterval or cfg.throttleInterval;

  /* The supervisor never executes the bundle binary; it asks LaunchServices to
      open the bundle, then watches for a process running from that bundle. */
  mkScript = name: app:
    let
      args = app.args or [ ];
      openArgs = lib.escapeShellArgs (
        [ "-g" "-a" app.path ] ++ lib.optionals (args != [ ]) ([ "--args" ] ++ args)
      );
    in
    pkgs.writeShellScriptBin "${module}-${name}" ''
      set -eu

      app=${lib.escapeShellArg app.path}
      bundleDir="$app/Contents/MacOS/"

      # Any process running from the bundle's MacOS directory is the app; an
      # exact prefix match keeps this free of pattern escaping.
      isRunning() {
        /bin/ps -Ao comm= \
          | /usr/bin/awk -v dir="$bundleDir" 'index($0, dir) == 1 { found = 1 } END { exit !found }'
      }

      launch() {
        if ! /usr/bin/open ${openArgs}; then
          echo >&2 "${module}: ${name}: could not open $app"
        fi
      }

      ${if restartFor app == "onLogin" then ''
        if ! isRunning; then
          launch
        fi
      '' else ''
        while :; do
          if ! isRunning; then
            launch
          fi
          sleep ${pollFor app}
        done
      ''}
    '';

  mkAgent = name: app: {
    enable = true;
    config = {
      Label = agentLabel name;
      ProgramArguments = [ "${mkScript name app}/bin/${module}-${name}" ];
      LimitLoadToSessionType = "Aqua";
      ProcessType = cfg.processType;
      RunAtLoad = true;
      ThrottleInterval = throttleFor app;
    } // lib.optionalAttrs ((app.environmentVariables or { }) != { }) {
      EnvironmentVariables = app.environmentVariables;
    } // lib.optionalAttrs (restartFor app == "always") {
      KeepAlive = true;
      /* LaunchServices starts the app outside this process group, so launchd
          must not clean it up when the supervisor is restarted. */
      AbandonProcessGroup = true;
    };
  };

  checks = lib.concatMapStrings
    (name: ''
      checkApp ${lib.escapeShellArg name} ${lib.escapeShellArg apps.${name}.path} ${lib.escapeShellArg (agentLabel name)}
    '')
    (lib.attrNames apps);

in {

  options.services.${module} = {

    enable = lib.mkEnableOption module;

    apps = lib.mkOption {
      type = lib.types.attrsOf (lib.types.either lib.types.str appType);
      default = { };
      example = lib.literalExpression ''
        {
          Mail = "/System/Applications/Mail.app";
          Clash = { path = "/Applications/Clash Verge.app"; restart = "onLogin"; };
        }
      '';
      description = ''
        Apps to keep alive, as `name -> path` or `name -> { ... }`. Each entry
        becomes a LaunchAgent named `keep-alive.<name>`.
      '';
    };

    onMissing = lib.mkOption {
      type = lib.types.enum [ "disable" "error" ];
      default = "disable";
      description = ''
        What to do at activation when an entry's path does not exist.
        `disable` reports the path and unloads that one agent; `error` reports
        every missing path and fails activation.
      '';
    };

    restart = lib.mkOption {
      type = lib.types.enum [ "always" "onLogin" ];
      default = "always";
      description = ''
        `always` reopens the app within `pollInterval` seconds whenever it is
        not running, including after a normal quit. `onLogin` only opens it
        once, when the agent loads.
      '';
    };

    pollInterval = lib.mkOption {
      type = lib.types.ints.positive;
      default = 3607;
      example = 10;
      description = ''
        Seconds between two liveness checks, 3607 (a prime just above an hour)
        by default. Lower it for apps that should come back faster.
      '';
    };

    throttleInterval = lib.mkOption {
      type = lib.types.ints.positive;
      default = 10;
      description = "Minimum seconds between two launches of an agent.";
    };

    processType = lib.mkOption {
      type = lib.types.enum [ "Background" "Standard" "Adaptive" "Interactive" ];
      default = "Background";
      description = ''
        launchd process type for the supervisor. It does not affect the app,
        which LaunchServices starts as a regular application.
      '';
    };
  };

  config = lib.mkIf cfg.enable {

    assertions = [ {
      assertion = lib.all (app: lib.hasPrefix "/" app.path) (lib.attrValues apps);
      message = "services.${module}: app paths must be absolute.";
    } ];

    launchd.agents = lib.mkIf isDarwin (
      lib.mapAttrs' (name: app: lib.nameValuePair (agentName name) (mkAgent name app)) apps
    );

    /* Paths cannot be checked at build time: `nix build` evaluates purely, so
        the module verifies them on the host instead, after Home Manager has
        installed the agents. */
    home.activation.keepAliveApps = lib.mkIf (isDarwin && apps != { }) (
      lib.hm.dag.entryAfter [ "setupLaunchAgents" ] ''
        onMissing=${cfg.onMissing}
        launchAgentsDir=${lib.escapeShellArg launchAgentsDir}
        domain="gui/$UID"
        missing=()

        # The installed plist is a copy of the one in the current generation,
        # so only remove the file while it still matches what we generated.
        removeAgent() {
          local name="$1" label="$2"
          local src="$newGenPath/LaunchAgents/$label.plist"
          local dst="$launchAgentsDir/$label.plist"

          run /bin/launchctl bootout "$domain/$label" >/dev/null 2>&1 || true

          if [[ -e $dst && ! -e $src ]]; then
            warnEcho "${module}: $name: leaving $dst alone, it is not from this generation"
            return 0
          fi
          if [[ -e $dst ]] && ! cmp -s "$src" "$dst"; then
            warnEcho "${module}: $name: leaving $dst alone, its contents changed"
            return 0
          fi

          verboseEcho "${module}: $name: removing $dst"
          run rm -f "$dst"
        }

        checkApp() {
          local name="$1" path="$2" label="$3"

          if [[ -d $path/Contents/MacOS ]]; then
            return 0
          fi

          missing+=("$name ($path)")
          errorEcho "${module}: $name: missing $path"

          if [[ $onMissing == disable ]]; then
            removeAgent "$name" "$label"
          fi
        }

        ${checks}

        if (( ''${#missing[@]} > 0 )); then
          errorEcho "${module}: missing app bundles:"
          for entry in "''${missing[@]}"; do
            errorEcho "${module}:   $entry"
          done
          if [[ $onMissing == error ]]; then
            exit 1
          fi
          errorEcho "${module}: their LaunchAgents stay unloaded until the paths exist"
        fi

        unset -f checkApp removeAgent
      ''
    );
  };

}
