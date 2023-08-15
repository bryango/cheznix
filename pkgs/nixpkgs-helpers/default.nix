{ lib, runCommand } @ args:

let

  source = ./files;
  importer = args.importer or srcImporter;
  files = importer.load {
    src = source;
    loader = importer.loaders.verbatim;
  };

  srcImporter.loaders.verbatim = {};
  srcImporter.load = { src, ... }:
  let

    paths = lib.filesystem.listFilesRecursive src;

    ## expose helpers via attributes
    genHelperInfo = path: let
        ## relative path, without leading "/"
        ## ... need `toString`, otherwise the path is nix-stored
        relative = lib.removePrefix "${toString src}/" (toString path);
        id = lib.removeSuffix ".nix" relative;
      in {
        name = id;
        value = path;
      };
  
  in builtins.listToAttrs (map genHelperInfo paths);

in (
  runCommand "nixpkgs-helpers" { } ''
    ln -s -T "${source}" "$out"
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
