## a fork of nixpkgs:nixos/modules/config/shells-environment.nix

{ lib, pkgs, config, ... }:

let

  inherit (lib)
    types
    mkOption
    literalExpression
    ;

  ## TODO: passed from system-manager:nix/modules/environment.nix
  ## ... instead of hard-coded
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

    system.build.setEnvironment = pkgs.writeText "set-environment" "";

    /* WIP: /etc/shells
      - https://gitlab.archlinux.org/archlinux/packaging/packages/zsh/-/blob/main/zsh.install
      - https://github.com/numtide/system-manager/blob/main/nix/modules/default.nix
      - https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/programs/zsh/zsh.nix
    */
    build.scripts =
      let
        etcShells = "/etc/shells";
        shells = map utils.toShellPath config.environment.shells;

        ## WIP: this doesn't actually work:
        ## https://wiki.archlinux.org/title/Shell_package_guidelines
        buildScriptForShell = index: shell: {
          name = "etcShellsScript-${toString index}";
          value = pkgs.writeShellScript "etc-shells-${toString index}" ''

              ## remove all ${pathDir} from ${etcShells}
              sed -i -r "|^${pathDir}.*$|d" "${etcShells}"

              ## remove all /nix/store paths from ${etcShells}
              sed -i -r "|^/nix/store.*$|d" "${etcShells}"

              ## add ${shell}
              [[ -x "${shell}" ]] \
                && grep -Fqx "${shell}" "${etcShells}" \
                || echo "${shell}" >> "${etcShells}"
          '';
        };

        buildScripts = lib.imap1 buildScriptForShell shells;
      in
      builtins.listToAttrs buildScripts;
  };
}
