{ lib
, makeBinaryWrapper
, symlinkJoin
, tectonic
, biber
}:

let

  pname = "tectonic-with-biber";
  inherit (biber) version;

  ## manually construct the name for symlinkJoin
  name = "${pname}-${version}";

  meta = tectonic.meta // {
    inherit name;
    description = "Modernized TeX/LaTeX engine, with biber for bibliography";
    longDescription = ''
      This package wraps tectonic with biber without triggering rebuilds.
      The biber executable is exposed with a version suffix, such as
      `biber-2.17`, to prevent conflict with the `biber` associated with
      the texlive bundles. Example use:

          ## pin last successful build of biber-2.17
          ## ... from https://hydra.nixos.org/build/202359527
          let
            rev = "40f79f003b6377bd2f4ed4027dde1f8f922995dd";
            nixpkgs_biber217 = import (builtins.fetchTarball {
              url = "https://github.com/NixOS/nixpkgs/archive/''${rev}.tar.gz";
              sha256 = "1javsbaxf04fjygyp5b9c9hb9dkh5gb4m4h9gf9gvqlanlnms4n5";
            }) {};
          in
            tectonic-with-biber.override {
              biber = nixpkgs_biber217.biber;
            }

      This serves as a fix for:
      - https://github.com/NixOS/nixpkgs/issues/88067
      - https://github.com/tectonic-typesetting/tectonic/issues/893
    '';
  };

  ## produce the correct `meta.position`
  pos = builtins.unsafeGetAttrPos "description" meta;

in

symlinkJoin {

  inherit pname version name meta pos;

  ## biber is **not** directly exposed in paths
  paths = [ tectonic ];

  nativeBuildInputs = [ makeBinaryWrapper ];

  ## tectonic runs biber when it detects it needs to run it, see:
  ## https://github.com/tectonic-typesetting/tectonic/releases/tag/tectonic%400.7.0
  postBuild = ''
    wrapProgram $out/bin/tectonic \
      --prefix PATH : "${lib.getBin biber}/bin"
    makeBinaryWrapper "${lib.getBin biber}/bin/biber" \
      $out/bin/biber-${biber.version}
  '';
  ## the biber executable is exposed as `biber-${biber.version}`

  passthru = { inherit biber; };

}
