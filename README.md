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

hydra: https://hydra.nixos.org/jobset/nixpkgs/trunk/evals
- pick a _finished_ jobset
- alternatively, use `hydra-check --channel master`

find the package:
- choose a successful build in the hydra web interface
- locate the desired closure with `$nix_store_path`
- inspect: `nix path-info -rsh "$nix_store_path" --store https://cache.nixos.org | sort -hk2`

install the package:
- temporarily: `nix profile install`
- permanently: `builtins.fetchClosure`
- from source: pin nix registry / flake inputs to a nice commit from hydra

## nix intro: more pacman beyond pacman

- install from pacman for the root `nix-daemon`, following [the wiki](https://wiki.archlinux.org/title/Nix)
- `profile`: virtual environments, managed with `nix profile`
- `registry`: index of packages (flakes), managed with `nix registry`
- `channels`: _deprecated_, special `profiles` which contain snapshots of the `nixpkgs` repo

See: https://nixos.org/manual/nix/unstable/package-management/profiles.html

```bash
$ ls -alF --time-style=+ --directory ~/.nix* | sed -E "s/$USER/\$USER/g" 
.nix-channels  ## deprecated, removed
.nix-defexpr/
.nix-profile -> .local/state/nix/profiles/profile/
```

## registry

This is the package index for nix, analogous to that of a traditional package manager such as pacman, but made reproducible through version pinning. This is just like a modern build system such as cargo. 

```bash
nix registry list

## refresh index & pin (to latest / to hash)
nix registry pin nixpkgs
nix registry add nixpkgs github:NixOS/nixpkgs/dc6263a3028cb06a178c16a0dd11e271752e537b
```

One can also alias / override / add local repositories; this is done automatically in [**cheznix:** modules/flake-channels.nix](modules/flake-channels.nix).

