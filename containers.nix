/**
  Containerd containers managed by Nix.

  References:
  - https://github.com/pdtpartners/nix-snapshotter/compare/dfa03e51808ed274c69e5544509987b839c2a68a
  - https://github.com/nix-community/docker-nixpkgs/tree/main/images/nix
  - https://nixos.org/manual/nixpkgs/unstable/#sssec-pkgs-dockerTools-helpers-caCertificates
  - https://github.com/NixOS/nix/blob/master/docker.nix
*/

{
  nix-snapshotter,
  bash,
  lib,
  coreutils,
  nix,
  dockerTools,
  curl,
  ...
}:

rec {
  base =
    nix-snapshotter.buildImage {
      resolvedByNix = true;
      name = "base";
      tag = "latest";
      fromImage = dockerTools.buildLayeredImage {
        name = "nix-db";
        includeNixDB = true;
        compressor = "none";
      };
      copyToRoot = [
        dockerTools.caCertificates
        coreutils
        nix
        bash
        curl
      ];
      config.entrypoint = [ "${lib.getExe bash}" ];
    }
    // {
      runCopyToContainerd = base.copyToContainerd { };
    };
}
