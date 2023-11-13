# Install old _binaries_ in nix

One of the biggest strengths of nix is that it has the power to manage multiple versions of a package side by side.
Unfortunately (and ironically), there isn't a nice and easy UI to achieve this natively,
as complained in https://github.com/NixOS/nixpkgs/issues/93327 among many other places.

I think I have found a perfect solution to this common problem (at least for my own use case).
In summary, to install an old package with nix, we simply need to:
- locate a **cached** old version of the package on hydra: https://hydra.nixos.org
- install the cached **closure** via `nix profile install`
  or [`builtins.fetchClosure`](https://nixos.org/manual/nix/stable/language/builtins#builtins-fetchClosure)

> In this post, we focus on the solution with the next-gen `nix commands` in pure evaluation mode,
which is fully compatible with flakes.
I believe it is also possible to achieve the same results using `builtins.storePath` in impure mode,
along with the older `nix-env` command, but I haven't tested that myself.

## locate a _cached_ old version

For a casual user like me, most of the time I would like to have the old version of a package that I can directly download and install (like a savage Windows user). This is the thing that current discussions of the problem tend to overlook: for an average user, we would like to have **an old _binary_**, not just some source revision in nixpkgs.

But this is perfectly achievable, due to the almighty public CI service hydra.
The whole of nixpkgs is built by hydra every now and then,
therefore it includes the binary archive of almost all versions that have ever existed on the nixpkgs repo.

As far as I know, the easiest way to query the hydra database is to use the CLI utility [`hydra-check`](https://github.com/nix-community/hydra-check).
For example, if we want to install a binary build of `pulsar` (specified by the attribute name), we can find its latest cache with:
```console
$ hydra-check --channel master pulsar ## `--channel master` for the nixpkgs master branch
Build Status for pulsar.x86_64-linux on master
✔ pulsar-1.109.0 from 2023-10-07 - https://hydra.nixos.org/build/237386313
```
Open the returned link in the browser, click on the hyperlinked title `pulsar.x86_64-linux`,
and we shall find all historic builds of `pulsar`.

![Historic hydra builds of `pulsar`](https://github.com/bryango/cheznix/assets/26322692/a88b68f1-1072-49b6-8834-347c18c27d26)

Locate the desired version, navigate to the "Details" tab, and we shall find its output store path:

![Hydra build details of `pulsar`](https://github.com/bryango/cheznix/assets/26322692/ccb5f1bc-e783-4031-95cb-3ae8b890ad66)

```
/nix/store/mqk6v4p5jzkycbrs6qxgb2gg4qk6h3p1-pulsar-1.109.0
```
That's all we need.

> Alternatively, if `hydra-check` is not available, we can query hydra through the web interface directly:
> https://hydra.nixos.org/jobset/nixpkgs/trunk/evals.
> Pick a _finished_ jobset, and look for a successful build underneath that.

### inspection (optional)
The binary closure and its dependencies can be inspected with the command:
```bash
nix_store_path=/nix/store/mqk6v4p5jzkycbrs6qxgb2gg4qk6h3p1-pulsar-1.109.0
nix path-info --store https://cache.nixos.org -rhs "$nix_store_path" | sort -hk2
```
By piping into `sort -hk2` we sort the returned paths by size.
Alternatively, there is a nice little web interface to inspect the binary cache: https://wh0.github.io/nix-cache-view/.
Just input the hash we've obtained above, and we get a [nice summary](https://wh0.github.io/nix-cache-view/view.html?cache_base=https%3A%2F%2Fcache.nixos.org&hash=mqk6v4p5jzkycbrs6qxgb2gg4qk6h3p1) of its dependencies and contents.


## install the cached _closure_

```bash
nix profile install /nix/store/mqk6v4p5jzkycbrs6qxgb2gg4qk6h3p1-pulsar-1.109.0
```
That's it! done! 🎆

A few comments are in order:
- This is a dirty one-shot install in the style of `sudo apt install`. For a more declarative approach, please keep on reading.
- I am using the next-gen `nix profile` command, which requires `experimental-features = nix-command flakes` in `/etc/nix/nix.conf`. I think `nix-env -i` works equally well, but I haven't tested it.

## declarative install with `builtins.fetchClosure`

There is an inherent _impureness_ in binary packages, as they rely heavily on the trust of caching servers.
Therefore, it has not been easy to install a binary closure declaratively.
Nevertheless, owing to the recent inclusion of [`builtins.fetchClosure`](https://nixos.org/manual/nix/stable/language/builtins#builtins-fetchClosure) in stable nix, this can now be achieved with the following config:
```conf
## /etc/nix/nix.conf
experimental-features = nix-command flakes fetch-closure
```
with an additional `fetch-closure` flag. The closure package can then be defined as the following overlay:
```nix
final: prev:
{
  pulsar_1_109 = {
    inherit (prev.pulsar) pname;
    version = "1.109.0";
    outPath = builtins.fetchClosure {
      fromPath = /nix/store/mqk6v4p5jzkycbrs6qxgb2gg4qk6h3p1-pulsar-1.109.0;
      fromStore = "https://cache.nixos.org";
      inputAddressed = true;
    };
  };
}
```
And that's it. We can now use `pulsar_1_109` like a usual package!

> I believe the same can be achieved with `builtins.storePath` in impure mode, but I haven't tested it.
