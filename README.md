# cheznix
nix home-manager setup, documented below.

## bootstrap

- install nix, via either [pacman](https://wiki.archlinux.org/title/Nix) or the [determinate installer](https://github.com/DeterminateSystems/nix-installer)
- set up [`nix.conf`](https://github.com/bryango/chezroot/blob/master/etc/nix/nix.conf) and restart `nix-daemon.service`
- check that `~/.nix-profile` & `$PATH` is correctly set up, in [`~/.profile`](https://github.com/bryango/cheznous/blob/NOUS/.profile)
- clone and apply the profile:
```bash
dest="$HOME/.config/home-manager"

nix flake clone github:bryango/cheznix --dest "$dest" && cd "$dest" || exit
nix run . -- switch --update-input nixpkgs-config --show-trace
## ^ home-manager provided as flake `packages.${system}.default`
```
- upon successful activation, one can replace the `nix run` commands with `{home,system}-manager` in `$PATH`

## nix: more pacman beyond pacman

Why?
- arch & AUR is perfect.
- unfortunately, Real Life is messy.

Multiple versions are sometimes a requirement, which pacman refuses to handle. Fortunately, we have nix!
- read on for some quick tips
- jump to [#intro](#nix-intro) for some basics

## strategies

For package management:
- use nix at the user level, as much as possible
- fall back to pacman, AUR or whatever for system / graphical / incompatible packages

Some limitations of nix packages in non-NixOS:
- gui apps are often faulty: lack of graphics, theming, audio, input method...
- apps that rely on system bin / lib may have troubles

For home (dot)files management,
- do not over manage,
  leave that to [**chezmoi**](https://github.com/bryango/cheznous)
- ... unless they need to be configured,
  in which case one can make use of [**modules**](./modules/)
- in particular, migrate non-secret config from `~/.secrets` to `home.nix`

## binary cached versions

use hydra: https://hydra.nixos.org/jobset/nixpkgs/trunk/evals
- pick a _finished_ jobset
- alternatively, use `hydra-check --channel master`

find the package:
- choose a successful build in the hydra web interface
- locate the desired closure with `$nix_store_path`
- inspect: `nix path-info --store https://cache.nixos.org -rhs "$nix_store_path" | sort -hk2`

install the package:
- temporarily: `nix profile install`
- permanently: `builtins.fetchClosure`
- from source: pin nix registry / flake inputs to a nice commit from hydra

## cli quick start

```bash
nix search nixpkgs neovim

## check output store path & size
nix eval --raw nixpkgs#neovim.outPath \
| xargs nix path-info --store https://cache.nixos.org \
   -hs  ## human readable size
        ## -r: recurse closures, -S: closure size

## dirty install
nix profile install nixpkgs#neovim
  ## --profile "~/.local/state/nix/profiles/$profile"
```

### debugging

```bash
nix profile diff-closures
  ## --profile "~/.local/state/nix/profiles/$profile"

## derivations
nix-diff ~/.local/state/nix/profiles/$profile-{$old,$new}-link

nix why-depends \
  --derivation \
  --all \
  --precise
```

### garbage collection

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
home-manager expire-generations '2023-07-04 08:00'

# all-in-one util
nix-collect-garbage  # --delete-older-than, --max-freed, --dry-run
```

To get an overview of package sizes,
```bash
nix path-info --all -hs | sort -hk2
```

# nix intro

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
- `$gen` in `$profile-$gen-link` is the `generation` number.
- `profile` is the default user profile
- `/nix/var/nix/profiles/default -> /nix/var/nix/profiles/per-user/root/profile` is the default profile

The files are well-documented in [`man nix-env`](https://nixos.org/manual/nix/unstable/command-ref/nix-env.html) and [`man nix3-profile`](https://nixos.org/manual/nix/unstable/command-ref/new-cli/nix3-profile), except for the last one: `/nix/var/nix/profiles/default` which seems to be undocumented but useful.

> **History:** the profile locations have been changed before! See https://github.com/NixOS/nix/pull/5226. The new defaults seem more reasonable.

## nixpkgs `staging` branch

https://github.com/NixOS/nixpkgs/blob/master/CONTRIBUTING.md#staging

PRs merged into the `staging` branch are not immediately built by hydra.
They are manually batched and merged into `staging-next` for a mass hydra rebuild.
Therefore a commit in the middle of a staging branch may _not_ enjoy any useful binary cache, at that time in the commit history.
To find a cached build we must go all the way to the branching point (either in its future or in its past).

As an example, let us consider https://github.com/NixOS/nixpkgs/pull/246963.
We would like to undo the commits.
However, it is merged into `staging`, so its parent may not (and indeed does not) have binary cache and will take forever to build!
To find a cached build:

### back to the future from its ancestors

We check its ancestors successively, for a commit that belongs to some PR which has been merged into `master`, not `staging`.
[This commit](https://github.com/NixOS/nixpkgs/commit/3e483a0e1fc75a57e2ef551c416f52ec598a426d) is an automatic sync from the hydra built `staging-next` to `staging`. At some time in its future, it is manually merged back into `staging-next` and finally back into `master` (https://github.com/NixOS/nixpkgs/pull/248496). This is the branch point which lies in the _future_ of the PR https://github.com/NixOS/nixpkgs/pull/246963 of our interest.

In order to get rid of https://github.com/NixOS/nixpkgs/pull/246963 which comes from `staging`, we can simply go to the parent (https://github.com/NixOS/nixpkgs/pull/249953) of the branch point (https://github.com/NixOS/nixpkgs/pull/248496). The price is that we also lose everything else that comes along the `staging` merge. To get a list of `staging-next` merges, go to:

https://github.com/NixOS/nixpkgs/pulls?q=head%3Astaging-next+sort%3Acreated-desc

### straight to the future along its descendants

This is not possible from the GitHub webui, but once we have a local checkout of nixpkgs, we can do:
```bash
rev=92e83bfab5d0dac17ed868fd1ba2118193597f42  ## pr #246963
git log --reverse --ancestry-path --topo-order "$rev"^..master
```
scroll down towards the future and look for the next `staging-next` merge. This is the branch point #248496 as above.
