## a fork of nixpkgs:nixos/modules/config/shells-environment.nix

{ lib, pkgs, config, ... }:

let

  inherit (lib)
    types
    mkOption
    literalExpression
    concatStringsSep
    ;

  ## TODO: passed from system-manager:nix/modules/environment.nix
  ## ... instead of hard-coding
  pathDir = "/run/system-manager/sw";

  ## nixpkgs:nixos/lib/utils.nix
  utils = {
    # Returns a system path for a given shell package
    toShellPath = shell:
      if types.shellPackage.check shell then
        "${pathDir}${shell.shellPath}"
      else if types.package.check shell then
        throw "${shell} is not a shell package"
      else
        shell;
  };

in

{
  options = {
    environment.shells = mkOption {
      default = [ ];
      example = literalExpression "[ pkgs.bashInteractive pkgs.zsh ]";
      description = lib.mdDoc ''
        A list of permissible login shells for user accounts.
      '';
      type = types.listOf (types.either types.shellPackage types.path);
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
        script = ''
          touch "${etcShells}"

          ## remove all ${pathDir} from ${etcShells}
          sed -i -r "/^${lib.escape ["/"] pathDir}.*$/d" "${etcShells}"

          ## remove all /nix/store paths from ${etcShells}
          sed -i -r "/^${lib.escape ["/"] "/nix/store"}.*$/d" "${etcShells}"

          ${concatStringsSep "\n" (map addShell shells)}
        '';
      };
  };

}
