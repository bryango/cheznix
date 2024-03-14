{ nixpkgs
, applyPatches
, fetchpatch
, lib
, ...
}:

assert lib.assertMsg (lib ? importer) ''
  an importer with the interface of https://github.com/nix-community/haumea
  must be supplied through `lib.importer`. This is used to import the patches
  listed under the current directory.
'';

let

  # inherit (lib) fakeHash;

  prHashes = {
    "293730" = "sha256-UaoylWGFAaR7xZTYurwwrd9IhfuNqxH70ixEfeaMoJY=";
  };

  prPatches = lib.mapAttrs
    (pr: hash: fetchpatch {
      url = "https://patch-diff.githubusercontent.com/raw/NixOS/nixpkgs/pull/${pr}.patch";
      inherit hash;
    })
    prHashes;

  patches = prPatches // lib.importer.load {
    src = ./.;
    loader = with lib.importer; [
      (matchers.extension "patch" loaders.path)
    ];
  };

in
(applyPatches {
  name = "nixpkgs-patched";
  src = nixpkgs;
  /**
    It may be possible to create a `fetchpatchLocal` by overriding the
    `fetchurl` of `fetchpatch`, but not for now.
    See: https://github.com/NixOS/nixpkgs/blob/master/pkgs/build-support/fetchpatch/default.nix
  */
  patches = lib.attrValues patches;
  /**
    Turn the patched nixpkgs into a fixed-output derivation;
    this is useful for distribution but inconvenient for prototyping,
    so it's easier to comment out the `outputHash*` when developing nixpkgs.
  */
  # outputHash = "sha256-7909mxdVXItcwhoUJ1eASxY4J4i2+eAH8MDa5LjYpO0=";
  # outputHashMode = "recursive";
  # outputHashAlgo = "sha256";
}).overrideAttrs {
  preferLocalBuild = false;
  allowSubstitutes = true;
}
