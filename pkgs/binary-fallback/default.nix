{ stdenvNoCC, writeShellApplication, substituteAll, which
, name, runtimeInputs }:

writeShellApplication {
  inherit name;
  runtimeInputs = [ stdenvNoCC which ] ++ runtimeInputs;
  text = builtins.readFile ( substituteAll {
    src = ./binary-fallback.sh;
    inherit name;
  });
}
