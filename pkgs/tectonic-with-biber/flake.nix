{
  description = "Tectonic with biber override";

  inputs = {
    nixpkgs.url = "nixpkgs";

    /* pin last successful build of e.g. biber-2.17
        from https://hydra.nixos.org/build/202359527
    */
    nixpkgs_biber.url =
      "github:NixOS/nixpkgs/40f79f003b6377bd2f4ed4027dde1f8f922995dd";
  };

  outputs = { self, nixpkgs, nixpkgs_biber }:
    let
      inherit (nixpkgs) lib;

      forAllSystems = lib.genAttrs lib.systems.flakeExposed;
      mkPackages = system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          pkgs_biber = nixpkgs_biber.legacyPackages.${system};

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
