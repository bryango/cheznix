/** pulsar from ci builds, instead of github releases */

{ pulsar, fetchzip, lib }:

let

  version = "1.119.0";

in

pulsar.overrideAttrs {
  inherit version;
  src =
    # let
    #   /**
    #     Pulsar follows a semi-automated release process. Look under github
    #     actions for the [artifact] corresponding to the release commit.
    #     nightly.link is a helpful service for concurrent downloads.
      
    #     [artifact]: https://nightly.link/pulsar-edit/pulsar/actions/runs/9949008125

    #     - nix store add-path # NOT add-file, different hashing scheme
    #     - cachix push chezbryan
    #     - cachix pin chezbryan pulsar-source
    #     - nix store make-content-addressed # check that hash is _not_ changed

    #     See also: https://github.com/NixOS/nix/issues/6210#issuecomment-1060834892
    #   */
    #   path = /nix/store/rvvbgyfk49axxlgvd9hxgi1jgkppanv6-Linux.pulsar-1.119.0.tar.gz;
    # in
    # builtins.fetchClosure {
    #   fromStore = "https://chezbryan.cachix.org";
    #   /** it seems that cachix doesn't advertise ca-derivations;
    #           no worries, just treat them as input addressed: */
    #   toPath = path;
    #   fromPath = path;
    # };
    (fetchzip {
      url = "https://api.github.com/repos/pulsar-edit/pulsar/actions/artifacts/1704337116/zip";
      extension = "zip";
      hash = lib.fakeHash;
      pname = "pulsar-ubuntu";
      netrcImpureEnvVars = ["GITHUB_TOKEN"];
      inherit version;
      stripRoot = false;
      postFetch = ''
        mv "$out" "$unpackDir"
        mv "$unpackDir"/*.tar.gz "$out"
      '';
    }).overrideAttrs {
      postHook = ''
        curlOptsList="'--header' 'Authorization: Bearer $GITHUB_TOKEN'"
      '';
    };
}
