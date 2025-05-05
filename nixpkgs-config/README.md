# nixpkgs-config
nixpkgs with personalized config

## this repo ...
- contains nixpkgs overrides that are "universal",
  i.e. valid across all of my personal projects,
  but may not be upstreamed to the official nixpkgs for various reasons;
  for example, this repo permits `python2` which is marked insecure upstream
- exposes `legacyPackages.${system}` just like the nixpkgs flake
  thus can be referenced in the same way:
```nix
## flake: inputs =
{
  nixpkgs.url = "github:bryango/nixpkgs-config";
  ## ...
}
```
