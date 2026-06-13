# Override inventory

This document records the local Nix override surface in this repository.

## Method

The inventory was collected with a source scan for Nix override forms:

```bash
rg --no-config -n \
  "(^|[^[:alnum:]_'.-])(override[A-Za-z0-9_']*)\s*(=|\()|\.(override[A-Za-z0-9_']*)\b" \
  --glob '*.nix' --glob '!**/.git/**'
```

Each hit was then classified by reachability and intent:

- Active configuration overrides: used directly by `home.nix`, `flake.nix`, or imported helper modules.
- Active overlay/package overrides: exposed through `nixpkgs-config` overlays or package outputs. Some are not installed in every current home profile, but remain reachable package attributes.
- Package helper overrides: reusable package constructors whose override is part of the helper implementation.
- Dormant overrides: syntactically active, but currently no-op or only active under a narrow condition.
- Unused/dead code: commented-out override call sites, files under explicit `unused` or `__unused` paths, and obsolete reference implementations.

Plain prose comments containing the word "override" are ignored unless they describe dead override code.

## Active configuration overrides

- [`flake.nix`](../flake.nix): `home-manager.override` drops `nixos-option` from Home Manager's package set because option inspection does not work for flakes.
- [`system-modules/scripts/system-manager-packages-patching.nix`](../system-modules/scripts/system-manager-packages-patching.nix): `system-manager-unwrapped.overrideAttrs` removes numtide cache arguments from `system-manager-engine`, then `upstreamPackages.default.override` wires the patched unwrapped package into the exposed `system-manager`.
- [`home.nix`](../home.nix): `dufs.overrideAttrs` adds `SSL_CERT_FILE` during checks on Linux. This is marked `FIXME` pending upstream `NixOS/nixpkgs#526701`.
- [`home.nix`](../home.nix): `pipx.overridePythonAttrs` disables failing tests on Linux. This is marked `FIXME` pending upstream `NixOS/nixpkgs#522307`.
- [`home.nix`](../home.nix): `gimp3-with-plugins.override` selects the Linux plugin set, currently including `resynthesizer`.
- [`home.nix`](../home.nix): `qt6Packages.fcitx5-with-addons.override` swaps in `fcitx5-configtool-no-kcm`.
- [`overlay.nix`](../overlay.nix): `neovim.override` disables Ruby support.
- [`overlay.nix`](../overlay.nix): `redshift.override` disables geolocation and appindicator support, followed by `overrideAttrs` to rewrap the binary.
- [`overlay.nix`](../overlay.nix): `buildEnv.overrideAttrs` applies only to `home-manager-path` and adds `glibcLocales` to `disallowedRequisites`.

Note: `home.nix` short-circuits to `machines/crab` when `attrs.hostname == "crab"`, so the `home.nix` package-list overrides above apply to the non-crab home configurations.

## Active overlay and package exports

These live under `nixpkgs-config` and are reachable through the personalized nixpkgs overlay/package outputs.

- [`nixpkgs-config/patches/default.nix`](../nixpkgs-config/patches/default.nix): `fetchpatch2.override` customizes `fetchurl` so local patch files can be trimmed and hashed like fetched patches.
- [`nixpkgs-config/patches/default.nix`](../nixpkgs-config/patches/default.nix): local `overrideAttrs = patched.overrideAttrs or (_: patched)` preserves a passthru hook even when `applyPatches` returns an unoverrideable value.
- [`nixpkgs-config/overlays/mods.nix`](../nixpkgs-config/overlays/mods.nix): `jujutsu.overrideAttrs` pins an unstable source, refreshes `cargoDeps`, and forces locale variables for checks.
- [`nixpkgs-config/overlays/mods.nix`](../nixpkgs-config/overlays/mods.nix): `texstudio.overrideAttrs` creates `texstudio-lazy_resize` with the PDF resize patch.
- [`nixpkgs-config/overlays/mods.nix`](../nixpkgs-config/overlays/mods.nix): `git.overrideAttrs` creates non-distributed `git-master` from an upstream commit and adds autoreconf setup.
- [`nixpkgs-config/overlays/mods.nix`](../nixpkgs-config/overlays/mods.nix): `kdePackages.fcitx5-configtool.override` creates `fcitx5-configtool-no-kcm`.
- [`nixpkgs-config/overlays/mods.nix`](../nixpkgs-config/overlays/mods.nix): `byobu.override` removes `screen` and `vim` from `byobu-with-tmux`.
- [`nixpkgs-config/overlays/mods.nix`](../nixpkgs-config/overlays/mods.nix): `prev.wol.overrideAttrs` adds a Darwin compile flag for bundled gettext. This is marked `FIXME` pending upstream `NixOS/nixpkgs#519842`.
- [`nixpkgs-config/pkgs/pulsar-from-ci.nix`](../nixpkgs-config/pkgs/pulsar-from-ci.nix): `pulsar.overrideAttrs` points Pulsar at a GitHub Actions artifact, with a nested fetcher `overrideAttrs` to pass the token header and normalize permissions.
- [`nixpkgs-config/flake.nix`](../nixpkgs-config/flake.nix): `self.packages.${system}.niz.override { source = null; }` makes the `niz` dev shell independent of the source tree.

## Package helper overrides

- [`nixpkgs-config/pkgs/binary-fallback/default.nix`](../nixpkgs-config/pkgs/binary-fallback/default.nix): `writeShellApplication(...).overrideAttrs` rewires `passAsFile`, creates a custom `textPath`, and patches the build command so the fallback wrapper can compose generated text.
- [`nixpkgs-config/pkgs/nixpkgs-helpers/default.nix`](../nixpkgs-config/pkgs/nixpkgs-helpers/default.nix): `runCommand(...).overrideAttrs` attaches helper script paths as passthru attributes.
- [`nixpkgs-config/niz/package.nix`](../nixpkgs-config/niz/package.nix): `buildRustPackage(...).overrideAttrs` is conditional on `isDevShell`; when active, it swaps in empty sources, adds dev tools, and sets Rust debugging environment.

## Dormant or currently no-op overrides

- [`nixpkgs-config/overlays/mods.nix`](../nixpkgs-config/overlays/mods.nix): `nixVersions.latest.appendPatches(...).overrideAllMesonComponents` is active, but its body currently only contains a commented-out version tweak.
- [`nixpkgs-config/overlays/mods.nix`](../nixpkgs-config/overlays/mods.nix): `tailscale.overrideAttrs { }` is active, but currently changes nothing.

## Unused or dead override code

- [`home.nix`](../home.nix): commented `pkgs.nerdfonts.override` example.
- [`overlay.nix`](../overlay.nix): commented Home Manager override block migrated to `flake.nix`.
- [`nixpkgs-config/flake.nix`](../nixpkgs-config/flake.nix): commented Python 2 GIMP override. It is retained only as a removal note after Python 2 support was dropped from GIMP; see `NixOS/nixpkgs#479956`.
- [`nixpkgs-config/overlays/mods.nix`](../nixpkgs-config/overlays/mods.nix): commented alternative `nixVersions.stable.overrideAttrs` block.
- [`nixpkgs-config/overlays/__unused/hm.nix`](../nixpkgs-config/overlays/__unused/hm.nix): dead Home Manager passthru override. The exported overlay names are `flake`, `mods`, `nixgl`, and `utils`, so `__unused` is not part of the active overlay set.
- [`nixpkgs-config/pkgs/unused/git-master/default.nix`](../nixpkgs-config/pkgs/unused/git-master/default.nix): obsolete full Git package reference with `subversionClient.override` and a test `overrideAttrs`.
- [`nixpkgs-config/pkgs/unused/tectonic-biber-flake.nix`](../nixpkgs-config/pkgs/unused/tectonic-biber-flake.nix): obsolete Tectonic-with-biber flake reference.
- Other files under [`nixpkgs-config/pkgs/unused`](../nixpkgs-config/pkgs/unused) are treated as dead reference code unless imported elsewhere in the future.
