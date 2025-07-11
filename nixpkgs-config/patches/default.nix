{ src ? /**
  `src` defaults to the nixpkgs store path. However, it is recommended to
  manually supply the nixpkgs flake inputs, which is automatically locked
  to a `narHash`.

  Without a locked hash the nixpkgs source would be duplicated in the nix
  store during _every_ eval, which leads to a huge performance hit.
  */
  builtins.path {
    inherit path;
    name = "source";
    # sha256 = "sha256-5US0/pgxbMksF92k1+eOa8arJTJiPvsdZj9Dl+vJkM4=";
  }
, importer ? (
    import
      (fetchFromGitHub {
        owner = "nix-community";
        repo = "haumea";
        rev = "v0.2.2";
        hash = "sha256-FePm/Gi9PBSNwiDFq3N+DWdfxFq0UKsVVTJS3cQPn94=";
      })
      { inherit lib; }
  )
, path
, applyPatches
, fetchpatch2
, fetchFromGitHub
, lib
, buildPackages
, trimPatch ? (
    fetchpatch2.override ({ patchutils, ... }: {
      /** adapted to handle local files */
      fetchurl =
        ({ name ? "", src, hash ? lib.fakeHash, passthru ? { }, postFetch, nativeBuildInputs ? [ ], ... }:
          buildPackages.stdenvNoCC.mkDerivation {
            inherit src;
            dontUnpack = true;
            name = if name != "" then name else baseNameOf (toString src);
            outputHashMode = "recursive";
            outputHashAlgo = null;
            outputHash = hash;
            passthru = { inherit src trimPatch; } // passthru;
            nativeBuildInputs = [ patchutils ] ++ nativeBuildInputs;

            /** `postFetch` hook provided by `fetchpatch` */
            inherit postFetch;
            installPhase = ''
              cp -r $src $out
              runHook postFetch
            '';
          });
    })
  )
}:

let

  /** the set of patches to apply on `src` */
  patches = prPatches // localPatches // {
  };

  /** a set of nixpkgs pull requests ids and their respective hashes */
  prHashes = {
  };

  /**
    files that ends with `.patch` will be loaded automatically;
    optionally, hash local patches to probably speed up the build
    with fixed-output derivations (FODs).
  */
  localHashes = {
  };

  # now we process the supplied patches ...

  prPatches = lib.mapAttrs
    (pr: hash: fetchpatch2 {
      url = "https://patch-diff.githubusercontent.com/raw/NixOS/nixpkgs/pull/${pr}.patch";
      inherit hash;
    })
    prHashes;

  localPatches = lib.pipe
    {
      src = ./.;
      loader = with importer; [
        (matchers.extension "patch" loaders.path)
      ];
    }
    [
      importer.load
      (lib.mapAttrs (name: src:
        if localHashes ? ${name}
        then trimPatch { inherit name src; hash = localHashes.${name}; }
        else src
      ))
    ];

  patched = applyPatches {
    name = "nixpkgs-patched";
    inherit src;
    /**
      It may be possible to create a `fetchpatchLocal` by overriding the
      `fetchurl` of `fetchpatch`, but this hasn't yet been implemented, for now.
      See: https://github.com/NixOS/nixpkgs/blob/master/pkgs/build-support/fetchpatch/default.nix
    */
    patches = lib.attrValues patches;
  };
  
  # this takes care of the case where `patches` is empty.
  overrideAttrs = patched.overrideAttrs or (_: patched);

in

overrideAttrs ({ passthru ? { }, ... }: {
  passthru = passthru // { inherit patches trimPatch; };
  preferLocalBuild = false;
  allowSubstitutes = true;
  /**
    Turn the patched nixpkgs into a fixed-output derivation;
    this is useful for distribution but inconvenient for prototyping,
    so it's easier to comment out the `outputHash*` when developing nixpkgs.
  */
  # outputHash = "sha256-3t6PVr8ww3w21S3jq9fb/9GdtXirn3fpC0+FM0/8X1o=";
  # outputHashMode = "recursive";
  # outputHashAlgo = "sha256";
})
