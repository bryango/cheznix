# cheznix
nix home-manager setup, documented below.

## nix: more pacman beyond pacman

Why?
- arch & AUR is perfect.
- unfortunately, Real Life is messy.

Multiple versions are sometimes a requirement, which pacman refuses to handle. Fortunately, we have nix, which is also perfect!
- read on for some quick tips
- jump to [#intro](#nix-intro) for some basics

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

## nix intro

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

One can also alias / override / add local repositories; this is done automatically in [**modules/flake-channels.nix**](modules/flake-channels.nix).

## cli quick start

```bash
nix search nixpkgs neovim

## check output store path & size
nix eval --raw nixpkgs#neovim.outPath \
| xargs nix path-info --store https://cache.nixos.org \
   -sh ## human readable size
## -r: recurse closure, -S: closure size

## dirty install
nix profile install nixpkgs#neovim
  ## --profile "~/.local/state/nix/profiles/$profile"
```

## garbage collection

See https://nixos.org/manual/nix/unstable/package-management/garbage-collection.html.

```bash
# check access points (roots)
nix-store --gc --print-roots

# actual garbage collection
nix-store -v --gc

# further optimisation
nix-store --optimise
```

More AGRESSIVE:

```bash
# delete old generations
nix profile wipe-history --older-than "$num"d

# all-in-one util
nix-collect-garbage  # --delete-older-than, --max-freed, --dry-run
```

To get an overview of package sizes,
```bash
du -h --max-depth=1 /nix/store --exclude=/nix/store/.links | sort -h
```

## binary cache `substituters`

Here we follow the guidance of [**tuna**](https://mirrors.tuna.tsinghua.edu.cn/help/nix/).

- `~/.config/nix/nix.conf` managed in [**home.nix**](home.nix)
- [`/etc/nix/nix.conf`](https://github.com/bryango/chezroot/blob/-/etc/nix/nix.conf)

_Note:_ either `trusted-users` or `trusted-substituters` has to be declared in the root config [`/etc/nix/nix.conf`](https://github.com/bryango/chezroot/blob/-/etc/nix/nix.conf). Otherwise `substituters` will be ignored. This is not emphasized, neither in the manual nor the error message. See https://github.com/NixOS/nix/issues/6672. 

## convenient `channel`

**Note:** `channel` is deprecated but we can set up a convenient compatible layer with the flake registry; see the relevant settings in [**modules/flake-channels.nix**](modules/flake-channels.nix). 

To add a channel temporarily, one can specify:
- `$NIX_PATH`, or
- `--include nixpkgs=channel:$channel`, or
- `-I nixpkgs=flake:$channel`

such that nixpkgs is easily available via `import <nixpkgs> {}`. The list of channels are found in:
- registry: `nix registry list`
- mirror: https://mirrors.tuna.tsinghua.edu.cn/nix-channels/
- upstream: https://nixos.org/channels/

## `profiles`

```bash
$ ls -alF --time-style=+ ~/.local/state/nix/profiles | sed -E "s/$USER/\$USER/g"          
profile -> profile-$gen-link/
profile-$gen-link -> /nix/store/#some-hash
```
- The number `$gen` in `$profile-$gen-link` is the `generation`.
- `profile` is the default user profile

The default system profile, as documented in [`man nix-env`](https://nixos.org/manual/nix/unstable/command-ref/nix-env.html), is `/nix/var/nix/profiles/default`.

**Note:** the user profiles' location have changed! See https://github.com/NixOS/nix/pull/5226. 
- `/nix/var/nix/profiles/per-user/$USER`: previous default
- `~/.local/state/nix/profiles`: current default

Manual migration might be required for some commands to work properly. 
