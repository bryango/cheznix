final: prev:

let

  inherit (prev)
    lib
    callPackage
    recurseIntoAttrs;

  hostSymlinks = recurseIntoAttrs (callPackage ./../pkgs/host-links.nix {});

  collectFlakeInputs = name: flake: {
    ${name} = flake;
  } // lib.concatMapAttrs collectFlakeInputs (flake.inputs or {});
  ## https://github.com/NixOS/nix/issues/3995#issuecomment-1537108310

in { ## be careful of `rec`, might not work

  inherit collectFlakeInputs;

  ## exec "$name" from system "$PATH"
  ## if not found, fall back to "$package/bin/$name"
  binaryFallback = name: package: callPackage ./../pkgs/binary-fallback {
      inherit name package;
    };

  ## create "bin/$name" from a template
  ## with `pkgs.substituteAll attrset`
  binarySubstitute = name: attrset: prev.writeScriptBin name (
    builtins.readFile (prev.substituteAll attrset)
  );

  ## some helper functions
  nixpkgs-helpers = callPackage ./../pkgs/nixpkgs-helpers {};

  ## links to host libraries
  inherit hostSymlinks;
  inherit (hostSymlinks)
    host-usr
    host-locales;

}
