{ lib
, tectonic
, callPackage
, fetchpatch
}:

let
  biber = callPackage ./biber.nix { };
  tests = callPackage ./tests.nix { };
in

tectonic.overrideAttrs (prevAttrs: {

  patches = [
    /*
      Provides a version lock of the tectonic web bundle for reproducible builds
      by specifying the environment variable `TECTONIC_WEB_BUNDLE_LOCKED`.
      This patch should be removed once the upstream PR is merged.
    */
    (fetchpatch {
      url = "https://patch-diff.githubusercontent.com/raw/tectonic-typesetting/tectonic/pull/1131.patch";
      hash = "sha256-lnV4ZJLsAB0LC6PdKNjUreUPDKeD+L5lPod605tQtYo=";
    })
    # consistent `--web-bundle` CLI
    (fetchpatch {
      url = "https://patch-diff.githubusercontent.com/raw/tectonic-typesetting/tectonic/pull/1132.patch";
      hash = "sha256-fyRro616ItoYMLcCff8BzFyOI3J8Ize9TLh2O2utvlU=";
    })
  ];

  /*
    The version locked tectonic web bundle, redirected from:
      https://relay.fullyjustified.net/default_bundle_v33.tar
    To check for updates: look up `get_fallback_bundle_url` from:
      https://github.com/tectonic-typesetting/tectonic/blob/master/crates/bundles/src/lib.rs
  */
  TECTONIC_WEB_BUNDLE_LOCKED = "https://data1.fullyjustified.net/tlextras-2022.0r0.tar";

  passthru = {
    unwrapped = tectonic;
    inherit
      biber
      tests
    ;
  };

  # tectonic runs biber when it detects it needs to run it, see:
  # https://github.com/tectonic-typesetting/tectonic/releases/tag/tectonic%400.7.0
  postInstall = ''
    wrapProgram $out/bin/tectonic \
      --prefix PATH : "${lib.getBin biber}/bin"
  '' + (prevAttrs.postInstall or "");

  meta = prevAttrs.meta // {
    description = "Tectonic, wrapped with the correct biber version";
    longDescription = ''
      This package wraps tectonic with a compatible version of biber.
      The tectonic web bundle is pinned to ensure reproducibility.
      This serves as a downstream fix for:
      - https://github.com/tectonic-typesetting/tectonic/issues/893
    '';
    maintainers = with lib.maintainers; [ bryango ];
  };

})
