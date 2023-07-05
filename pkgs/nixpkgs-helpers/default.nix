{ lib, runCommand }:

let

  sourceDir = ./files;

  paths = lib.filesystem.listFilesRecursive sourceDir;
  genPathInfo = path: rec {
    basename = builtins.baseNameOf path;
    id = lib.removeSuffix ".nix" basename;
    source = path;
    relative = lib.removePrefix (toString sourceDir) (toString path);
  };
  helpers = map genPathInfo paths;

  ## expose helpers via attributes
  generateAttrs = helper: {
    name = helper.id;
    value = helper.source;
  };
  files = builtins.listToAttrs (map generateAttrs helpers);

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
