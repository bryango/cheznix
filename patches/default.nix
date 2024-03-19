{ path
, applyPatches
, fetchpatch
, fetchFromGitHub
, lib
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
, buildPackages
, trimPatch ? (
    fetchpatch.override {
      fetchurl =
        ({ name ? "", src, hash ? lib.fakeHash, passthru ? { }, postFetch }:
          buildPackages.stdenvNoCC.mkDerivation {
            inherit src;
            dontUnpack = true;
            name = if name != "" then name else baseNameOf (toString src);
            outputHashMode = "recursive";
            outputHashAlgo = null;
            outputHash = hash;
            passthru = { inherit src trimPatch; } // passthru;

            /** `postFetch` hook provided by `fetchpatch` */
            inherit postFetch;
            installPhase = ''
              cp -r $src $out
              runHook postFetch
            '';
          });
    }
  )
}:

let

  /** `fakeHash` is useful for version bumps; commented out when unused. */
  # inherit (lib) fakeHash;

  patches = prPatches // localPatches // {
    /** for grammarly */
    "nodejs_16_undrop" = fetchpatch {
      url = "https://github.com/NixOS/nixpkgs/commit/b013b3ee50cace81104bc29b8fc4496a3093b5cd.patch";
      hash = "sha256-mibE20naWnud1bsbVFsU55ctoycIhY5NQBD4Oz9WSD4=";
      revert = true;
    };
    "nodejs_16_repatch" = trimPatch {
      src = ./271362-nodejs-16-to-revert.patch.manual;
      hash = "sha256-ACgYGoFiS3Tudbhk8ttIftOktjlOVgpZLm7aD1JbgcU=";
      revert = true;
    };
    "grammarly_unbroken" = fetchpatch {
      url = "https://patch-diff.githubusercontent.com/raw/NixOS/nixpkgs/pull/293630.patch";
      hash = "sha256-vwLpW1SRVzbHEUpgBnnGfkhMNX0k+C34FS/iFRsq4NQ=";
      revert = true;
    };
  };

  prHashes = {
    /** wechat-uos */
    "293730" = "sha256-UaoylWGFAaR7xZTYurwwrd9IhfuNqxH70ixEfeaMoJY=";
  };

  localHashes = {
    "python2-wcwidth-fix-build" = "sha256-OxxEYxwoxP+XHCfN5BtRDzYzLRhK6/l5BRB1Uo3pBNQ=";
  };

  prPatches = lib.mapAttrs
    (pr: hash: fetchpatch {
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

in
(applyPatches {
  name = "nixpkgs-patched";
  src =
    /** this is necessary to prevent double copies of nixpkgs */
    builtins.path {
      inherit path;
      name = "source";
    };
  /**
    It may be possible to create a `fetchpatchLocal` by overriding the
    `fetchurl` of `fetchpatch`, but this hasn't yet been implemented, for now.
    See: https://github.com/NixOS/nixpkgs/blob/master/pkgs/build-support/fetchpatch/default.nix
  */
  patches = lib.attrValues patches;
  passthru = { inherit patches trimPatch; };
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
