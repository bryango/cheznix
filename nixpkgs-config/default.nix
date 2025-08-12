{
  flakeSystem ? args.system or builtins.currentSystem or "aarch64-darwin",
  ...
}@args:

let

  lockFile = builtins.fromJSON (builtins.readFile ./flake.lock);
  flake-compat-node = lockFile.nodes.${lockFile.nodes.root.inputs.flake-compat};
  flake-compat = builtins.fetchTarball {
    inherit (flake-compat-node.locked) url;
    sha256 = flake-compat-node.locked.narHash;
  };

  flake =
    (import flake-compat {
      src = ./.;
      copySourceTreeToStore = false;
    }).outputs;

  nixpkgs = flake.inputs.nixpkgs;
  lib = flake.lib;
  pkgs = flake.legacyPackages.${flakeSystem};

  /*
    prepare the arguments for the `nixpkgs` function

    Note:
    - "config.*ackageOverrides" will be overriden, not merged
    - "overlays" are composed by stacking them together
    - see e.g. home-manager|nixos: modules/misc/nixpkgs.nix
  */
  overlays = (pkgs.overlays or [ ]) ++ (args.overlays or [ ]);

  cleanedArgs = removeAttrs args [
    "flakeSystem"
    "overlays"
  ]; # ^ remove processed args

  passedArgs = lib.recursiveUpdate {
    inherit (pkgs) config;
    inherit overlays;
  } cleanedArgs;

in

import nixpkgs passedArgs
// {
  inherit flake;
}
