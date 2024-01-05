{ stdenvNoCC
, writeShellApplication
, substituteAll
, which
, name
, package
}:

writeShellApplication {
  inherit name;
  runtimeInputs = [ stdenvNoCC which ];
  text = ''
    source ${substituteAll {
      src = ./binary-fallback.sh;
      inherit name package;
    }}
  '';
}
