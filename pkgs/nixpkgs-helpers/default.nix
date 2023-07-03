{ lib, linkFarm }:

let

  ## target directory to host the helpers
  directory = ".";
  paths = lib.filesystem.listFilesRecursive ./files;
  genPathInfo = path: rec {
    basename = builtins.baseNameOf path;
    id = lib.removeSuffix ".nix" basename;
    source = path;
  };
  helpers = map genPathInfo paths;

  inherit (builtins) listToAttrs;

  ## gather helpers to the target directory
  generateLinks = helper: {
    name = "${directory}/${helper.basename}";
    value = helper.source;
  };
  links = listToAttrs (map generateLinks helpers);

  ## expose helpers via attributes
  generateAttrs = helper: {
    name = helper.id;
    value = helper.source;
  };
  files = listToAttrs (map generateAttrs helpers);

in (linkFarm "nixpkgs-helpers" links).overrideAttrs (
  prev: {
    ## make helpers accessible
    passthru = prev.passthru // files // {
      ## prevent mixing with other passthrus
      inherit files;
    };
  }
)
