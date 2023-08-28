{
  description = "Tectonic with biber override";

  inputs = {
    nixpkgs.url = "nixpkgs";

    /* pin last successful build of biber-2.17
        from https://hydra.nixos.org/build/202133264
    */
    nixpkgs_biber.url =
      "github:NixOS/nixpkgs/80c24eeb9ff46aa99617844d0c4168659e35175f";
  };

  outputs = { self, nixpkgs, nixpkgs_biber }:
    let
      inherit (nixpkgs) lib;

      forAllSystems = lib.genAttrs lib.systems.flakeExposed;
      mkPackages = system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          pkgs_biber = nixpkgs_biber.legacyPackages.${system}.pkgsStatic;

          inherit (pkgs) tectonic;
          inherit (pkgs_biber) biber;

          tectonic-with-biber = pkgs.callPackage ./. {
            inherit biber;
          };
        in
        {
          inherit tectonic biber tectonic-with-biber;
          default = tectonic-with-biber;
        };
    in
    {
      inherit (nixpkgs) legacyPackages;
      packages = forAllSystems mkPackages;
    };
}
