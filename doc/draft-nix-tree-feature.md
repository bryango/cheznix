# Feature: support `--store` for `nix path-info`

It would be great if nix-tree can pass along the `--store` option to `nix path-info`. That way, we can query a remote package without installing it first. I tried to implement this myself and turns out, I could not learn haskell in one night :crying_cat_face: (what is a _monad_...)

Currently, I can obtain the closure of e.g. `nixpkgs#hello` without installing it:
```console
$ nix eval --raw nixpkgs#hello | xargs nix path-info -rSh --store https://cache.nixos.org | sort -hk2
/nix/store/ayg5rhjhi9ic73hqw33mjqjxwv59ndym-xgcc-13.2.0-libgcc	 156.4K
/nix/store/05zbwhz8a7i2v79r9j21pl6m6cj0xi8k-libunistring-1.1  	   1.7M
/nix/store/m59xdgkgnjbk8kk6k6vbxmqnf82mk9s0-libidn2-2.3.4     	   2.1M
/nix/store/p3jshbwxiwifm1py0yq544fmdyy98j8a-glibc-2.38-27     	  31.1M
/nix/store/h92a9jd0lhhniv2q417hpwszd4jhys7q-hello-2.12.1      	  31.3M
```
But the dependency tree is flattened in the final output.
