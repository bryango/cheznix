# cheznix
nix home-manager setup, documented below.

## strategies

For package management:
- use nix at the user level, as much as possible
- fall back to pacman, AUR or whatever for system / graphical / incompatible packages

Some limitations of nix packages:
- gui apps are often faulty: lack of graphics, theming, audio, input method...
- apps that rely on system bin / lib may have troubles

For home (dot)files management,
- do not over manage,
  leave that to [**chezmoi**](https://github.com/bryango/cheznous)
- ... unless they need to be configured,
  in which case one can make use of [**modules**](./modules/)
- in particular, migrate non-secret config from `~/.secrets` to `home.nix`

## binary cached versions

- use `hydra-check --channel master`
- choose a successful build in the hydra web interface
- locate the desired closure with `$nix_store_path`
- inspect: `nix path-info -rsh "$nix_store_path" --store https://cache.nixos.org | sort -hk2`

install the package:
- temporarily: `nix profile install`
- permanently: `builtins.fetchClosure`
- from source: with the nixpkgs input from hydra
