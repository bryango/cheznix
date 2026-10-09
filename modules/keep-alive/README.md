# Keep-alive

Keeps bundled macOS apps running behind one LaunchAgent per app.

An app bundle cannot be executed directly. macOS kills protected apps such as
Mail at startup with `SIGKILL (Code Signature Invalid)` and a
`Launch Constraint Violation` in the crash log, so each agent supervises the app
through LaunchServices instead of running its binary.

```nix
services.keep-alive = {
  enable = true;
  apps = {
    Mail = "/System/Applications/Mail.app";
  };
};
```

An entry is either a path or an attrset with `path`, `args`,
`environmentVariables`, `restart`, `pollInterval`, and `throttleInterval`, for
example `SomeApp = { path = "/Applications/SomeApp.app"; restart = "onLogin"; }`.

Every entry generates a supervisor script and a LaunchAgent named
`keep-alive.<name>`. Each `pollInterval` seconds, 3607 (a prime just above an
hour) by default, the supervisor looks for a process whose executable lives in
the bundle's `Contents/MacOS`. If none is running it asks LaunchServices to open
the app in the background (`open -g -a`). It never executes the bundle binary,
and it never launches a second copy while one is already running. Lower
`pollInterval` for apps that should come back within seconds of being quit.

`restart = "always"` (the default) reopens the app whenever it disappears,
including after a deliberate quit, and keeps the supervisor itself alive under
`KeepAlive`. `onLogin` runs the check once when the agent loads, which gives
start-at-login without fighting the user; it installs no `KeepAlive`. Apps
listed here should not also be login items, or they may start twice.

Paths cannot be checked while the configuration is built, because `nix build`
evaluates purely and cannot see the host filesystem. The module checks them once
Home Manager installs the agents. With the default `onMissing = "disable"`, a
missing app is reported and its agent is unloaded and removed while the other
apps keep running; with `onMissing = "error"`, activation fails after reporting
every missing path.

Inspect one with
`launchctl print gui/$(id -u)/org.nix-community.home.keep-alive.<name>`, and
restart it with the same command plus `kickstart -k`.
