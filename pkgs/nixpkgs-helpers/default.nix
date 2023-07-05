{ lib, runCommand }:

let

  source = ./files;
  paths = lib.filesystem.listFilesRecursive source;

  ## expose helpers via attributes
  genHelperInfo = path: let
      ## relative path, without leading "/"
      relative = lib.removePrefix "${toString source}/" (toString path);
      id = lib.removeSuffix ".nix" relative;
    in {
      name = id;
      value = path;
    };

  files = builtins.listToAttrs (map genHelperInfo paths);

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
