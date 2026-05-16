/**
  Module to import all files in the `./etc` directory
  as entries in `environment.etc`
*/

{ lib, ... }:

let
  etcRoot = ./etc;
  toEtcEntry = path: {
    name = lib.removePrefix "${toString etcRoot}/" (toString path);
    value.source = path;
  };
in
{
  config.environment.etc = lib.listToAttrs (
    map toEtcEntry (lib.filesystem.listFilesRecursive etcRoot)
  );
}
