final: prev:

let

  inherit (prev)
    lib
    callPackage
    recurseIntoAttrs;

in

## be careful of `rec`, might not work
{

  ## customized `checkpointBuildTools` before upstreaming
  addCheckpointBuildHookOnlyOnce = old:
      let
        preBuild = old.preBuild or "";
        hookCmd = "runHook preCheckpointBuild";
      in
      preBuild + (lib.optionalString (!lib.hasInfix hookCmd preBuild) ''
        ${hookCmd}
      '');

  prepareCheckpointBuild = drv: drv.overrideAttrs (old: {
    outputs = [ "out" ];
    name = drv.name + "-checkpointArtifacts";
    preBuild = final.addCheckpointBuildHookOnlyOnce old;
    preCheckpointBuild = ''
      mkdir -p $out/sources
      { shopt -s dotglob; cp -r ./* $out/sources/; }
    '';
    installPhase = ''
      runHook preCheckpointInstall
      mkdir -p $out/outputs
      { shopt -s dotglob; cp -r ./* $out/outputs/; }
      runHook postCheckpointInstall
    '';
  });

  mkCheckpointBuild = drv: checkpointArtifacts:
    let
      inherit (prev) mktemp rsync;
    in
    drv.overrideAttrs (old: {
      preBuild = final.addCheckpointBuildHookOnlyOnce old;
      preCheckpointBuild = ''
        set -e
        sourceDifferencePatchFile=$(${mktemp}/bin/mktemp)
        diff -ur ${checkpointArtifacts}/sources ./ > "$sourceDifferencePatchFile" || true
        { shopt -s dotglob; rm -r ./*; } || true

        ${rsync}/bin/rsync \
          --checksum --times --atimes --chmod=+w \
          -r ${checkpointArtifacts}/outputs/ .
        patch -p 1 -i "$sourceDifferencePatchFile" || echo "$sourcePatch"
        ## ... do not panic when it's unsuccessful
        ## ... this happens when the source is unchanged
        rm "$sourceDifferencePatchFile"
      '';
    });

  addCheckpointArtifacts = drv:
    let
      checkpointArtifacts = final.prepareCheckpointBuild drv;
    in
    (
      final.mkCheckpointBuild drv checkpointArtifacts
    ).overrideAttrs (old: {
      passthru = (old.passthru or { }) // {
        inherit checkpointArtifacts;
      };
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
      ${name} = flake; ## "high level" inputs win
    };
}
