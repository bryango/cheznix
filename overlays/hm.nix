/** home-manager flake, imported from derivation */

final: prev:

let
  inherit (prev) home-manager fetchFromGitHub;
  src = fetchFromGitHub {
    name = "home-manager-source";
    owner = "nix-community";
    repo = "home-manager";
    rev = "97069e11282bd586fb46e3fa4324d651668e1886";
    hash = "sha256-otzfwp5EpQ6mlnASeGu0uSKoatlQnBvLv/f4JP+WtfA=";
  };
in
{
  home-manager = (home-manager.override {
    unixtools.hostname = prev.inetutils;
  }).overrideAttrs (finalAttrs: prevAttrs:
    let
      ## retrieve the unfixed flake outputs via an import from derivation
      inherit (import "${src}/flake.nix") outputs;
    in
    {
      inherit src;
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
