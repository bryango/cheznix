/** home-manager flake, imported from derivation */

final: prev:

let
  /** use the inputs of this current flake, exposed as `flakeSelf` */
  inherit (final.flakeSelf.inputs) nixpkgs;
in
{
  home-manager = prev.home-manager.overrideAttrs (finalAttrs: prevAttrs:
    let
      ## allow overriding `src` in later stages
      inherit (finalAttrs) src;
      ## retrieve the unfixed flake outputs via an import from derivation
      inherit (import "${src}/flake.nix") outputs;
    in
    {
      passthru = prevAttrs.passthru // {
        flake = (outputs {
          self = finalAttrs.passthru.flake;
          inherit nixpkgs;
        }) // {
          inherit (src) outPath;
        };
      };
    }
  );
}
