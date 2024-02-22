/** home-manager flake, imported from derivation */

final: prev:

let
  inherit (prev) home-manager;
  inherit (home-manager) src;
in
{
  home-manager = home-manager.overrideAttrs (finalAttrs: prevAttrs:
    let
      ## retrieve the unfixed flake outputs via an import from derivation
      inherit (import "${src}/flake.nix") outputs;
    in
    {
      passthru = prevAttrs.passthru // {
        flake = (outputs {
          self = finalAttrs.passthru.flake;
          inherit (final.flakeSelf.inputs) nixpkgs;
        }) // {
          inherit (src) outPath;
        };
      };
    }
  );
}
