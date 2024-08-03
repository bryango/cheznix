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
    fetchpatch.override ( { patchutils, ... }: {
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

  patches = prPatches // localPatches // {
    /** for grammarly */
    # "nodejs_16_undrop" = fetchpatch {
    #   revert = true;
    #   url = "https://github.com/NixOS/nixpkgs/commit/b013b3ee50cace81104bc29b8fc4496a3093b5cd.patch";
    #   hash = "sha256-mibE20naWnud1bsbVFsU55ctoycIhY5NQBD4Oz9WSD4=";
    # };
    # "nodejs_16_repatch" = trimPatch {
    #   revert = true;
    #   name = "node-16-repatch";
    #   src = ./271362-for-nodejs-16-to-revert.patch.manually;
    #   hash = "sha256-1k+IPHPjaR46BqVGTNoVQrJVWzpbn55cIj+bMSam5lY=";
    # };
    # /** grammarly: first undrop */
    # "grammarly_01_undrop" = fetchpatch {
    #   revert = true;
    #   /** dropped in https://github.com/NixOS/nixpkgs/pull/327313 */
    #   url = "https://github.com/NixOS/nixpkgs/commit/9d41920ce37dc45dc37279efb58bf52c36a1597e.patch";
    #   hash = "sha256-UBrFYtgI0wGniEGn2q6P4U0It2nGit1gsV97TfJe1og=";
    # };
    # /** grammarly: then unbroken */
    # "grammarly_02_unbroken" = fetchpatch {
    #   revert = true;
    #   url = "https://patch-diff.githubusercontent.com/raw/NixOS/nixpkgs/pull/293630.patch";
    #   hash = "sha256-vwLpW1SRVzbHEUpgBnnGfkhMNX0k+C34FS/iFRsq4NQ=";
    # };
  };

  /**
    a set of nixpkgs pull requests ids and their respective hashes
  */
  prHashes = {
  };

  /**
    files that ends with `.patch` will be loaded automatically
    optionally, hash local patches to probably speed up IFD
  */
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
