# cheznix
nix home-manager setup

## strategy
- do not over manage home files,
  leave that to [**chezmoi**](https://github.com/bryango/cheznous)
- ... unless they need to be configured,
  in which case one can make use of [**modules**](./modules/)

## binary cached versions

- use `hydra-check --channel master`
- choose a successful build in the hydra web interface
- locate the desired closure with `$nix_store_path`
- inspect: `nix path-info -rsh "$nix_store_path" --store https://cache.nixos.org | sort -hk2`

install the package:
- temporary: `nix profile install`
- permanent: `builtins.fetchClosure`
- from source: with the nixpkgs input from hydra
