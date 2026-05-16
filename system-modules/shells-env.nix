## a fork of nixpkgs:nixos/modules/config/shells-environment.nix

{
  lib,
  pkgs,
  config,
  utils,
  ...
}:

let

  inherit (lib)
    mkOption
    concatStringsSep
    ;

in

{
  imports = [
    ./stubs/shells-environment.nix
    ./stubs/network-interfaces.nix
  ];

  options = {
    environment.shells = mkOption {
      /**
        hook to add /run/system-manager prefixed shells,
        compatible with what system manager puts in /etc/passwd.
      */
      apply =
        shells:
        let
          currentSystemPrefix = "/run/current-system";
          systemManagerPrefix = "/run/system-manager";
          toSystemManagerShell =
            shell:
            let
              shellPath = toString (utils.toShellPath shell);
            in
            lib.optional (lib.hasPrefix currentSystemPrefix shellPath) "${systemManagerPrefix}${lib.removePrefix currentSystemPrefix shellPath}";
        in
        lib.unique (shells ++ lib.concatMap toSystemManagerShell shells);
    };
  };

  config = {
    systemd.services.etc-shells =
      let
        etcShells = "/etc/shells";
        shells = map utils.toShellPath config.environment.shells;
        addShell = shell: ''
          ## add ${shell}
          if [[ -x "${shell}" ]]; then
            grep -Fqx "${shell}" "${etcShells}" \
            || echo "${shell}" >> "${etcShells}"
          fi
        '';
      in
      {
        enable = true;
        description = "Update /etc/shells for system-manager shells";
        wantedBy = [ "system-manager.target" ];
        after = [ "system-manager-path.service" ];
        requires = [ "system-manager-path.service" ];

        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };

        path = with pkgs; [
          coreutils
          gnugrep
          gnused
        ];

        ## https://wiki.archlinux.org/title/Shell_package_guidelines
        ## first clean up all Nix managed shells, then add the ones we want
        script = ''
          touch "${etcShells}"

          sed -i -r "/^${lib.escape [ "/" ] "/run/system-manager/sw"}.*$/d" "${etcShells}"
          sed -i -r "/^${lib.escape [ "/" ] "/run/current-system/sw"}.*$/d" "${etcShells}"
          sed -i -r "/^${lib.escape [ "/" ] "/nix/store"}.*$/d" "${etcShells}"

          ${concatStringsSep "\n" (map addShell shells)}
        '';
      };
  };

}
