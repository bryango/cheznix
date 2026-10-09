# Keep-alive

Keeps bundled macOS apps running behind one LaunchAgent per app. Each entry
runs the app's real executable, so launchd supervises the app process itself
and can restart it after a crash or a quit.

```nix
services.keep-alive = {
  enable = true;
  apps = {
    Mail = "/System/Applications/Mail.app";
    Clash = {
      path = "/Applications/Clash Verge.app";
      keepAlive = "onCrash";
    };
  };
};
```

An entry is either a path or an attrset with `path`, `executable`, `args`,
`environmentVariables`, `keepAlive`, and `throttleInterval`. The executable is
read from the bundle's `CFBundleExecutable` unless it is set explicitly.

`keepAlive` defaults to `always`, which restarts the app after any exit,
including a deliberate quit. Use `onCrash` to keep the app down after a normal
quit; preventing an accidental Command-Q needs a keyboard layer such as
Karabiner instead. Apps listed here should not also be login items, or they may
start twice.

Paths cannot be checked while the configuration is built, because `nix build`
evaluates purely and cannot see the host filesystem. The module checks them once
Home Manager installs the agents. With the default `onMissing = "disable"`, a
missing app is reported and its agent is unloaded and removed, leaving the other
apps running; with `onMissing = "error"`, activation fails after reporting every
missing path.

The agents are named `keep-alive.<name>` and labelled
`org.nix-community.home.keep-alive.<name>`. On macOS, restart one with
`launchctl kickstart -k gui/$(id -u)/org.nix-community.home.keep-alive.<name>`.
