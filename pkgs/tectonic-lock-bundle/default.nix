{ lib
, tectonic-unwrapped
, tectonic
, biber-for-tectonic
, callPackage
, fetchpatch
}:

let

  # The version locked tectonic web bundle, redirected from:
  #   https://relay.fullyjustified.net/default_bundle_v33.tar
  # To check for updates, see:
  #   https://github.com/tectonic-typesetting/tectonic/blob/master/crates/bundles/src/lib.rs
  # ... and look up `get_fallback_bundle_url`.
  TECTONIC_WEB_BUNDLE_LOCKED = "https://data1.fullyjustified.net/tlextras-2022.0r0.tar";
  ## ^ TODO: define this in `passthru.bundle.url` when published

in

(tectonic.override {
  tectonic-unwrapped = tectonic-unwrapped.overrideAttrs (prevAttrs: {
    patches = (prevAttrs.patches or [ ]) ++ [
      /*
        Provides a consistent `--web-bundle` option across the CLIs. This enables
        a version lock of the tectonic web bundle for reproducible builds by
        specifying a default `--web-bundle` flag, which can be overridden as
        needed. This patch should be removed once the upstream PR is released:
          https://github.com/tectonic-typesetting/tectonic/pull/1132
      */
      (fetchpatch {
        url = "https://patch-diff.githubusercontent.com/raw/tectonic-typesetting/tectonic/pull/1132.patch";
        hash = "sha256-MFPU0t8ScsM9ap9/XHVkhp/8gTgmdpv6t03L4uzLZjM=";
      })
    ];
  });
}).overrideAttrs (finalAttrs: prevAttrs: {

  passthru = prevAttrs.passthru // {
    tests = callPackage ./tests.nix { };
    bundle.url = TECTONIC_WEB_BUNDLE_LOCKED;
  };

  # Replace the unwrapped tectonic with the one wrapping it with biber
  # `buildCommand` here is for overriding, when upstreamed simply modify `postBuild`
  buildCommand = prevAttrs.buildCommand + ''
    rm $out/bin/{tectonic,nextonic}

    makeWrapper ${lib.getBin prevAttrs.passthru.unwrapped}/bin/tectonic $out/bin/tectonic \
      --prefix PATH : "${lib.getBin biber-for-tectonic}/bin" \
      --add-flags "--web-bundle ${finalAttrs.passthru.bundle.url}"
    ln -s $out/bin/tectonic $out/bin/nextonic
  '';
})
