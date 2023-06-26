{ stdenvNoCC, writeShellApplication, substituteAll, which
, name, package }:

writeShellApplication {
  inherit name;
  runtimeInputs = [ stdenvNoCC which ];
  text = builtins.readFile ( substituteAll {
    src = ./binary-fallback.sh;
    inherit name package;
  });
}
