# generate the script used to activate the configuration.
{ config, lib, pkgs, ... }:

with lib;

let

  addAttributeName = mapAttrs (a: v: v // {
    text = ''
      #### Activation script snippet ${a}:
      _localstatus=0
      ${v.text}

      if (( _localstatus > 0 )); then
        printf "Activation script snippet '%s' failed (%s)\n" "${a}" "$_localstatus"
      fi
    '';
  });

  systemActivationScript = set: onlyDry: let
    set' = mapAttrs (_: v: if isString v then (noDepEntry v) // { supportsDryActivation = false; } else v) set;
    withHeadlines = addAttributeName set';
    # When building a dry activation script, this replaces all activation scripts
    # that do not support dry mode with a comment that does nothing. Filtering these
    # activation scripts out so they don't get generated into the dry activation script
    # does not work because when an activation script that supports dry mode depends on
    # an activation script that does not, the dependency cannot be resolved and the eval
    # fails.
    withDrySnippets = mapAttrs (a: v: if onlyDry && !v.supportsDryActivation then v // {
      text = "#### Activation script snippet ${a} does not support dry activation.";
    } else v) withHeadlines;
  in
    ''
      #!${pkgs.runtimeShell}

      systemConfig='@out@'

      export PATH=/empty
      for i in ${toString path}; do
          PATH=$PATH:$i/bin:$i/sbin
      done

      _status=0
      trap "_status=1 _localstatus=\$?" ERR

      # Ensure a consistent umask.
      umask 0022

      ${textClosureMap id (withDrySnippets) (attrNames withDrySnippets)}

    '';

  path = with pkgs; map getBin
    [ coreutils
      gnugrep
      findutils
      getent
      stdenv.cc.libc # nscd in update-users-groups.pl
      shadow
      nettools # needed for hostname
      util-linux # needed for mount and mountpoint
    ];

  scriptType = withDry: with types;
    let scriptOptions =
      { deps = mkOption
          { type = types.listOf types.str;
            default = [ ];
            description = lib.mdDoc "List of dependencies. The script will run after these.";
          };
        text = mkOption
          { type = types.lines;
            description = lib.mdDoc "The content of the script.";
          };
      } // optionalAttrs withDry {
        supportsDryActivation = mkOption
          { type = types.bool;
            default = false;
            description = lib.mdDoc ''
              Whether this activation script supports being dry-activated.
            '';
          };
      };
    in either str (submodule { options = scriptOptions; });

in

{

  ###### interface

  options = {

    system.activationScripts = mkOption {
      default = {};

      example = literalExpression ''
        { stdio.text =
          '''
            # Needed by some programs.
            ln -sfn /proc/self/fd /dev/fd
            ln -sfn /proc/self/fd/0 /dev/stdin
            ln -sfn /proc/self/fd/1 /dev/stdout
            ln -sfn /proc/self/fd/2 /dev/stderr
          ''';
        }
      '';

      description = lib.mdDoc ''
        A set of shell script fragments that are executed when a
        system configuration is activated.  Examples are updating
        /etc, creating accounts, and so on.  Since these are executed
        every time you run
        {command}`system-manager`, it's important that they are
        idempotent and fast.
      '';

      type = types.attrsOf (scriptType true);
      apply = set: set // {
        script = systemActivationScript set false;
      };
    };

    system.dryActivationScript = mkOption {
      description = lib.mdDoc "The shell script that is to be run when dry-activating a system.";
      readOnly = true;
      internal = true;
      default = systemActivationScript (removeAttrs config.system.activationScripts [ "script" ]) true;
      defaultText = literalMD "generated activation script";
    };

  };


  ###### implementation

  config = {

  };

}
