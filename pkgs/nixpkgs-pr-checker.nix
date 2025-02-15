{
  stdenvNoCC,
  gh,
}:

stdenvNoCC.mkDerivation {
  name = "nixpkgs-pr-checker";
  buildInputs = [ gh ];
  dontUnpack = true;
  dontBuild = true;
  installPhase = ''
    mkdir -p $out/bin

    # replace the first #! line
    sed '0,/^#!/s|^.*$|#!/bin/bash|' ${../pr-checker.sh} > $out/bin/$name

    chmod +x $out/bin/$name
  '';
}
