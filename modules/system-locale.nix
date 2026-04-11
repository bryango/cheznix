/**
  use the locale provided by the root system,
  instead of configuring it through home-manager.
*/

{ ... }:

{
  disabledModules = [
    ## https://github.com/nix-community/home-manager/issues/2333
    ## https://github.com/nix-community/home-manager/blob/master/modules/config/i18n.nix
    "config/i18n.nix"
  ];

  config = {
    home.sessionVariables = {
      LOCALE_ARCHIVE = "/usr/lib/locale/locale-archive";
    };
  };
}
