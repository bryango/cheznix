final: prev:

let

  inherit (prev)
    lib
    callPackage
    recurseIntoAttrs;

in

## be careful of `rec`, might not work
{
  addCheckpointArtifacts = drv:
    let
      inherit (prev.checkpointBuildTools)
        prepareCheckpointBuild
        ;
      checkpointArtifacts = prepareCheckpointBuild drv;
      inherit (prev) mktemp rsync;
    in
    drv.overrideAttrs (prevAttrs: {
      passthru = (prevAttrs.passthru or { }) // {
        inherit checkpointArtifacts;
      };
      preBuild = (prevAttrs.preBuild or "") + ''
        set -e

        ## handle removed files:
        sourcePatch=$(${mktemp}/bin/mktemp)
        diff -ur ${checkpointArtifacts}/sources ./ > "$sourcePatch" || true

        ## handle binaries:
        newSourceBackup=$(${mktemp}/bin/mktemp -d)
        shopt -s dotglob
        mv ./* "$newSourceBackup"

        ## clean up, do not panic when there is nothing left (expected)
        rm -r * || true

        ## layer 0: artifacts
        ${rsync}/bin/rsync \
          --checksum --times --atimes --chown=$USER:$USER --chmod=+w \
          -r ${checkpointArtifacts}/outputs/ .

        ## layer 1: handle removed files: patch source texts
        patch -p 1 -i "$sourcePatch" || true
        ## ... do not panic when its unsuccessful (remedied immediately)

        ## layer 2: handle binaries: overlay the new source
        ${rsync}/bin/rsync \
          --checksum --times --atimes --chown=$USER:$USER --chmod=+w \
          -r "$newSourceBackup"/ .

        ## clean up
        rm "$sourcePatch"
        rm -rf "$newSourceBackup"
      '';
    });

  ## some helper functions
  nixpkgs-helpers = callPackage ../pkgs/nixpkgs-helpers {
    inherit (final) importer;
  };

  ## link to host libraries
  hostSymlinks = recurseIntoAttrs (callPackage ../pkgs/host-links.nix { });
  inherit (final.hostSymlinks)
    host-usr
    host-locales;

  ## exec "$name" from system "$PATH"
  ## if not found, fall back to "$package/bin/$name"
  binaryFallback = name: package: callPackage ../pkgs/binary-fallback {
    inherit name package;
  };

  ## create "bin/$name" from a template
  ## with `pkgs.substituteAll attrset`
  binarySubstitute = name: attrset: prev.writeScriptBin name (
    builtins.readFile (prev.substituteAll attrset)
  );

  ## create package from `fetchClosure`
  closurePackage = import ../pkgs/closure-package.nix {
    inherit (prev) lib;
  };

  ## link farm all overlaid derivations
  ## this does not actually depend on `final` nor `prev` so is fully portable
  gatherOverlaid =

    { pkgs ? final # pkgs fixed point
    , attrOverlays ? final.attrOverlays # overlays as an attrset
    }:

    let

      lib = pkgs.lib;

      ## this actually advances the fixed point, but don't worry,
      ## we only use it to exact the package names:
      applied = lib.mapAttrs (name: f: f pkgs pkgs) attrOverlays;
      merged = lib.attrsets.mergeAttrsList (lib.attrValues applied);
      derivable = lib.filterAttrs (name: lib.isDerivation) merged;
      attrnames = lib.unique (lib.attrNames derivable);
      packages = lib.genAttrs attrnames (name: pkgs.${name});

      name = "user-drv-overlays";

    in
    {
      ${name} = pkgs.linkFarm name packages;
    };

  ## recursively collect & flatten flake inputs
  ## https://github.com/NixOS/nix/issues/3995#issuecomment-1537108310
  collectFlakeInputs = name: flake:
    let
      ## avoid infinite recursion from self references
      inputs = removeAttrs (flake.inputs or { }) [ name ];
    in
    lib.concatMapAttrs final.collectFlakeInputs inputs // {
      ${name} = flake;  ## "high level" inputs win
    };
}
