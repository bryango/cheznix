{ lib
, symlinkJoin
, makeBinaryWrapper
, tectonic
, biber
}:

symlinkJoin {
  name = "tectonic-with-biber-${biber.version}";

  ## biber is **not** directly exposed in paths
  paths = [ tectonic ];

  nativeBuildInputs = [ makeBinaryWrapper ];

  # Tectonic runs biber when it detects it needs to run it, see:
  # https://github.com/tectonic-typesetting/tectonic/releases/tag/tectonic%400.7.0
  postBuild = ''
    wrapProgram $out/bin/tectonic \
      --prefix PATH : "${lib.getBin biber}/bin"
    makeBinaryWrapper "${lib.getBin biber}/bin/biber" \
      $out/bin/biber-${biber.version}
  '';
  ## the biber executable is exposed as `biber-${biber.version}`

  inherit (tectonic) meta;
}
