final: prev:

let

  inherit (prev)
    lib
    callPackage
    recurseIntoAttrs;

in { ## be careful of `rec`, might not work

  ## some helper functions
  nixpkgs-helpers = callPackage ../pkgs/nixpkgs-helpers {
    inherit (final) importer;
  };

  ## recursively collect & flatten flake inputs
  ## https://github.com/NixOS/nix/issues/3995#issuecomment-1537108310
  collectFlakeInputs = name: flake: {
    ${name} = flake;
  } // lib.concatMapAttrs final.collectFlakeInputs (flake.inputs or {});

  ## link to host libraries
  hostSymlinks = recurseIntoAttrs (callPackage ../pkgs/host-links.nix {});
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
  closurePackage = import ../pkgs/closure-package.nix;

}
