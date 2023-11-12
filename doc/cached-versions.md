# Install cached old versions in nix

One of the biggest strengths of nix is that it has the power to manage multiple versions of a package side by side.
Unfortunately (and ironically), there isn't a nice and easy UI to achieve this natively,
as complained in https://github.com/NixOS/nixpkgs/issues/93327 among many other places.

I think I have found a perfect solution to this common problem (at least for my own use case).
In summary, to install an old package with nix, we simply need to:
- locate a **_cached_** old version of the package on https://hydra.nixos.org
- install the cached **_closure_** via `nix profile install`
  or [`builtins.fetchClosure`](https://nixos.org/manual/nix/stable/language/builtins#builtins-fetchClosure)

> In this post, we focus on the solution with the next-gen `nix commands` in pure evaluation mode,
which is fully compatible with flakes.
I believe it is also possible to achieve the same results using `builtins.storePath` in impure mode,
along with the older `nix-env` command, but I haven't tested that myself.

## locate a _cached_ old version

For a casual user like me, most of the time I would like to have the old version of a package that I can directly download and install (like a savage Windows user). This is the thing that current discussions of the problem tend to overlook: for an average user, we would like to have **an old binary**, not just some source hash for the nixpkgs source.

But this is perfectly achievable, due to the almighty public CI service hydra.
The whole of nixpkgs is built by hydra every now and then,
therefore it includes the binary archive of almost all versions that have ever existed on the nixpkgs repo.

use hydra: https://hydra.nixos.org/jobset/nixpkgs/trunk/evals
- pick a _finished_ jobset
- alternatively, use `hydra-check --channel master`


## install the cached version

Owing to the recent inclusion of [`builtins.fetchClosure`](https://nixos.org/manual/nix/stable/language/builtins#builtins-fetchClosure) in stable nix,

- turn on the `fetch-closure` experimental feature

find the package:
- choose a successful build in the hydra web interface
- locate the desired closure with `$nix_store_path`
- inspect: `nix path-info --store https://cache.nixos.org -rhs "$nix_store_path" | sort -hk2`

install the package:
- temporarily: `nix profile install`
- permanently: `builtins.fetchClosure`
- from source: pin nix registry / flake inputs to a nice commit from hydra
