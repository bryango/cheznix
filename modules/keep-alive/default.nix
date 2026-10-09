/** Keep bundled macOS apps alive through one LaunchAgent per app. */

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

      executable = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "Mail";
        description = ''
          Binary inside the bundle's `Contents/MacOS` directory. Defaults to
          the bundle's `CFBundleExecutable` at runtime.
        '';
      };

      args = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Extra arguments passed to the app executable.";
      };

      environmentVariables = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        default = { };
        description = "Environment variables set for the LaunchAgent.";
      };

      keepAlive = lib.mkOption {
        type = lib.types.enum [ "always" "onCrash" ];
        default = cfg.keepAlive;
        description = "Override the module-wide `keepAlive` policy.";
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

  keepAliveFor = app: app.keepAlive or cfg.keepAlive;
  throttleFor = app: app.throttleInterval or cfg.throttleInterval;

  /* The wrapper resolves the real executable and replaces itself with it, so
      launchd supervises the app process rather than the shell. */
  mkWrapper = name: app:
    let
      executable = app.executable or null;
    in
    pkgs.writeShellScriptBin "${module}-${name}" ''
      set -eu

      app=${lib.escapeShellArg app.path}
      executable=${lib.escapeShellArg (if executable == null then "" else executable)}

      if [[ ! -d $app/Contents/MacOS ]]; then
        echo >&2 "${module}: ${name}: app bundle is missing: $app"
        exit 1
      fi

      if [[ -z $executable ]]; then
        executable=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' \
          "$app/Contents/Info.plist" 2>/dev/null || true)
      fi

      if [[ ! -x $app/Contents/MacOS/$executable ]]; then
        echo >&2 "${module}: ${name}: no executable in $app/Contents/MacOS"
        exit 1
      fi

      exec "$app/Contents/MacOS/$executable" "$@"
    '';

  mkAgent = name: app: {
    enable = true;
    config = {
      Label = agentLabel name;
      ProgramArguments = [ "${mkWrapper name app}/bin/${module}-${name}" ] ++ (app.args or [ ]);
      LimitLoadToSessionType = "Aqua";
      ProcessType = cfg.processType;
      RunAtLoad = true;
      KeepAlive =
        if keepAliveFor app == "always" then true else { SuccessfulExit = false; };
      ThrottleInterval = throttleFor app;
      /* Apps that fork helpers must not have them killed on every respawn. */
      AbandonProcessGroup = true;
    } // lib.optionalAttrs ((app.environmentVariables or { }) != { }) {
      EnvironmentVariables = app.environmentVariables;
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
          Clash = { path = "/Applications/Clash Verge.app"; keepAlive = "onCrash"; };
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

    processType = lib.mkOption {
      type = lib.types.enum [ "Background" "Standard" "Adaptive" "Interactive" ];
      default = "Interactive";
      description = "launchd process type for the agents.";
    };

    keepAlive = lib.mkOption {
      type = lib.types.enum [ "always" "onCrash" ];
      default = "always";
      description = ''
        `always` restarts the app after every exit, including a normal quit.
        `onCrash` restarts it only after an unsuccessful exit.
      '';
    };

    throttleInterval = lib.mkOption {
      type = lib.types.ints.positive;
      default = 10;
      description = "Minimum seconds between two launches of the same app.";
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
