{ lib, runCommand }:

let

  sourceDir = ./files;

  paths = lib.filesystem.listFilesRecursive sourceDir;
  genPathInfo = path: rec {
    source = path;
    relative = lib.removePrefix "${toString sourceDir}/" (toString path);
    id = lib.removeSuffix ".nix" relative;
  };
  helpers = map genPathInfo paths;

  ## expose helpers via attributes
  genHelperAttrs = helper: {
    name = helper.id;
    value = helper.source;
  };
  files = builtins.listToAttrs (map genHelperAttrs helpers);

in (
  runCommand "nixpkgs-helpers" { } ''
    ln -s -T "${sourceDir}" "$out"
  ''
).overrideAttrs (
  prev: {
    ## make helpers accessible
    passthru = files // {
      ## prevent mixing with other passthrus
      inherit files;
    };
  }
)
