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
