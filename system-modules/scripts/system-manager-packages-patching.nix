/**
  Custom patching for the system-manager packages set.
*/

{
  # The `github:numtide/system-manager` flake source.
  system-manager,
  system,
}:

let
  upstreamPackages = system-manager.packages.${system};

  system-manager-unwrapped = upstreamPackages.system-manager-unwrapped.overrideAttrs (old: {
    postPatch = (old.postPatch or "") + ''
      substituteInPlace crates/system-manager-engine/src/register.rs \
        --replace-fail '        .arg("--extra-substituters")' "" \
        --replace-fail '        .arg("https://cache.numtide.com")' "" \
        --replace-fail '        .arg("--extra-trusted-public-keys")' "" \
        --replace-fail '        .arg("niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g=")' ""
    '';
  });

  # This is the wrapped binary package exposed to the local profile.
  patched = upstreamPackages.default.override {
    inherit system-manager-unwrapped;
  };
in

upstreamPackages
// {
  default = patched;
  inherit system-manager-unwrapped;
}
