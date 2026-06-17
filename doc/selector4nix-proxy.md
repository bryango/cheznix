# selector4nix proxy notes

`selector4nix` can be used as a local HTTP binary-cache proxy over multiple
upstream caches. This is useful for read-only commands such as `nix path-info`
or `nix-tree --store`, where a single Cachix cache may contain the root path but
not every dependency in the recursive closure.

## Build and run

Build the binary against this repo's pinned `nixpkgs` registry entry:

```bash
nix build github:StarryReverie/selector4nix#selector4nix --override-input nixpkgs nixpkgs
```

Run it from the repository root with the local config:

```bash
./result/bin/selector4nix --config-file ./selector4nix.toml
```

The config file is [`../selector4nix.toml`](../selector4nix.toml). It listens on
`127.0.0.1:5496` and uses the same upstream caches configured in Nix:

- `https://mirrors.tuna.tsinghua.edu.cn/nix-channels/store/`
- `https://chezbryan.cachix.org/`
- `https://cache.nixos.org/`
- `https://nix-community.cachix.org/`

## Query through the proxy

Point Nix at the local HTTP store:

```bash
nix path-info --json --recursive \
  --store http://127.0.0.1:5496/ \
  --extra-experimental-features "nix-command flakes" \
  /nix/store/3bbd0lhzwwxkp5jfnj6cwnbgxc14c9v0-ping
```

This should allow a recursive query to combine narinfo from different upstreams,
for example a root path from `chezbryan.cachix.org` and dependencies from
`cache.nixos.org` or a mirror.

## Useful checks

Check selector4nix directly for one narinfo:

```bash
curl -v http://127.0.0.1:5496/3bbd0lhzwwxkp5jfnj6cwnbgxc14c9v0.narinfo
```

Check which upstream caches are currently considered available:

```bash
curl -s http://127.0.0.1:5496/substituters/available
```

Check a single upstream directly:

```bash
nix path-info --store https://chezbryan.cachix.org \
  --extra-experimental-features "nix-command flakes" \
  /nix/store/3bbd0lhzwwxkp5jfnj6cwnbgxc14c9v0-ping
```

## Gotchas

- `--recursive` requires every referenced path to be valid in the selected
  store. A root path can exist in Cachix while a dependency is missing there.
- selector4nix caches both positive and negative narinfo lookups. There is no
  config-only negative-cache disable; use a short `cache.nar_info_lookup_ttl_secs`
  or restart the proxy to clear in-memory misses.
- If selector4nix is started with a persistent `--cache-dir` or
  `SELECTOR4NIX_CACHE_DIR`, stale misses can survive restarts until their stored
  expiry time. Use a fresh cache directory when debugging.
- Temporary network failures can make Nix disable a binary cache for about
  60 seconds. TLS or connect errors across all upstreams usually indicate
  connectivity trouble rather than missing narinfo.
- A single-path query without `--recursive` is a better test for whether the root
  narinfo exists in one cache. A recursive query tests the whole closure.
