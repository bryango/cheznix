## adapted from `redshift.nix`

{ instanceName, instanceCfg, xdgConfigHome, lib, pkgs, modulesPath, ... }:

let

  ## pretend the instance is a full-fledged module
  moduleName = instanceName;
  mainSection = "redshift";
  cfg = lib.recursiveUpdate {

      ## some presets
      enable = true;
      settings.${mainSection} = {
        adjustment-method = "randr";
      };

    } instanceCfg;

  ## pretend the instance config is the full config
  config = {
    services.${moduleName} =
      if (cfg.temperature.always or null) != null
      then lib.recursiveUpdate cfg {

        ## same temp for day and night
        temperature = with cfg.temperature; {
          day = always;
          night = always;
        };

        ## required, but doesn't matter in this case
        ## ... so just take Beijing:
        longitude = "116.4";
        latitude = "39.9";

        ## no need to fade
        settings.redshift.fade = 0;

      } else cfg;

    xdg.configHome = xdgConfigHome;
  };

  instanceModule = ({ config, ... }: (
    import (
      modulesPath + "/services/redshift-gammastep/lib/options.nix"
    ) {
      inherit config lib pkgs;
      inherit moduleName mainSection;

      programName = "Redshift";
      defaultPackage = pkgs.redshift;
      examplePackage = "pkgs.redshift";
      mainExecutable = "redshift";
      appletExecutable = "redshift-gtk";
      xdgConfigFilePath = "redshift/${moduleName}.conf";
      serviceDocumentation = "http://jonls.dk/redshift/";
    }
  ));

  ## a custom version of `dischargeProperties`
  ## https://github.com/NixOS/nixpkgs/blob/master/lib/modules.nix
  dischargeMkIf = def:
    if def._type or "" == "if" then
      if lib.isBool def.condition then
        if def.condition then
          dischargeMkIf def.content
        else null
      else
        throw "‘mkIf’ called with a non-Boolean condition"
    else if lib.isAttrs def then
      lib.mapAttrs (name: value: dischargeMkIf value) def
    else
      def;

  ## remove null valued attr
  removeNulls = lib.filterAttrsRecursive (name: value: value != null);

  updateInputs = { config, ... } @ inputs:
    lib.recursiveUpdate inputs (
      removeNulls (dischargeMkIf (instanceModule inputs))
    );

in updateInputs (updateInputs { inherit config; })
## ... somehow `lib.converge` does not work so do it manually
