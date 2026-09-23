# Personal dashboard

Runs an existing, built dashboard checkout using Nix's Node.js runtime.
The module does not install dependencies or rebuild the app at service startup.

```nix
services.personal-dashboard = {
  enable = true;
  directory = "${config.home.homeDirectory}/Documents/codex/dashboard";
};
```

`configFile` defaults to `directory/config.local.json`; `dataDirectory` defaults
to `directory/.dashboard-data`. Both are runtime paths. Configuration,
credentials, dependencies, and application state are not copied into the Nix store.
Listener settings and dashboard modules remain in the application's JSON config.

The module installs `personal-dashboard` (server) and `dashboard` (CLI), sharing
the same configuration and data directory. The application prevents the server
and conflicting CLI operations from holding the database lock simultaneously.

macOS uses `org.nix-community.home.personal-dashboard`, starting at login and
restarting after exit. Linux uses a systemd user service named
`personal-dashboard`, restarting on failure. This checkout enables it on
`memoriam` only.

After changing the app source, run its `pnpm build` in the checkout and restart
the service. On macOS, use
`launchctl kickstart -k gui/$(id -u)/org.nix-community.home.personal-dashboard`;
on Linux, use `systemctl --user restart personal-dashboard`.
