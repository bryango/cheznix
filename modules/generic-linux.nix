{ config, lib, pkgs, modulesPath, ... }:

let

  module = "targets/generic-linux.nix";

  config' = lib.recursiveUpdate config {
    targets.genericLinux.enable = true;
  };

  outputs = import (modulesPath + "/${module}") {
    config = config';
    inherit lib pkgs;
  };

in
let

  config = lib.head (lib.pushDownProperties outputs.config);

in {

  disabledModules = [ module ];

  inherit (outputs) imports options;
  config = {

    ## inherit selected config only
    assertions = config.assertions;

    # home.sessionVariables.XCURSOR_PATH
    #   = home.sessionVariables.XCURSOR_PATH;
    # systemd.user.sessionVariables.TERMINFO_DIRS
    #   = systemd.user.sessionVariables.TERMINFO_DIRS;

  };

}
