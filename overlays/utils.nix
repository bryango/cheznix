final: prev:

let

  inherit (prev)
    lib
    callPackage
    recurseIntoAttrs
    runCommand
    symlinkJoin
    writeShellApplication;

in

## be careful of `rec`, might not work
{

  ## some helper functions
  nixpkgs-helpers = callPackage ../pkgs/nixpkgs-helpers {
    inherit (final) importer;
  };

  ## link to host libraries
  hostSymlinks = recurseIntoAttrs (callPackage ../pkgs/host-symlinks.nix { });
  inherit (final.hostSymlinks)
    host-usr
    host-locales;

  ## exec "$name" from system "$PATH"
  ## if not found, fall back to "$package/bin/$name"
  binaryFallback = name: package: callPackage ../pkgs/binary-fallback {
    inherit name package;
  };

  ## create "bin/$name" from a template
  ## use `substitute` to emulate `pkgs.substituteAll attrset`
  binarySubstitute = name: attrset: runCommand name
    { inherit (attrset) src; }
    ''
      target="$out"/bin/${name}
      mkdir -p "$(dirname "$target")"
      substitute "$src" "$target" \
      ${
        lib.pipe attrset [
          (lib.flip removeAttrs [ "src" ])
          (lib.mapAttrsToList (key: value:
            lib.escapeShellArgs [ "--replace" "@${key}@" "${value}" ]
          ))
          toString
        ]
      }
      chmod +x "$target"
    '';

  ## steal the shellcheck commands from `writeShellApplication`
  shellCheckPhase = (writeShellApplication {
    name = "dummy";
    text = "";
  }).checkPhase;

  ## create package from `fetchClosure`
  closurePackage = callPackage ../pkgs/closure-package.nix { };

  undoWrapProgram = drv: symlinkJoin {
    name = "${drv.name}-undo-wrapped";
    paths = [ drv ];
    postBuild = ''
      cd $out/bin
      for entry in .*-wrapped; do
        target=''${entry#.}
        target=''${target%-wrapped}
        rm "$target" || true
        cp -f -T "$entry" "$target"
        rm "$entry"
      done
    '';
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
