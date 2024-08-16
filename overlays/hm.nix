/** home-manager flake, imported from derivation (IFD) */

final: { path, home-manager, ... }:

let
  /** retrieve the nixpkgs flake through an import from derivation (IFD) */
  nixpkgs = (import "${toString path}/flake.nix").outputs { self = nixpkgs; };
in
{
  home-manager = home-manager.overrideAttrs (finalAttrs: { passthru ? { }, ... }:
    let
      ## allow overriding `src` in later stages
      inherit (finalAttrs) src;
      inherit (finalAttrs.passthru) flake;
      ## retrieve the unfixed flake outputs via another IFD
      inherit (import "${src}/flake.nix") outputs;
    in
    {
      passthru = passthru // {
        flake = (outputs {
          self = flake;
          inherit nixpkgs;
        }) // {
          inherit (src) outPath;
        };
      };
    }
  );
}
