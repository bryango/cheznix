/** pulsar from ci builds, instead of github releases */

{ pulsar, fetchzip }:

/**
  Pulsar follows a semi-automated release process. Look under github
  actions for the [artifact] corresponding to the release commit.
  nightly.link is a helpful service for concurrent downloads.

  [artifact]: https://nightly.link/pulsar-edit/pulsar/actions/runs/10413849888

  To include the build artifact in nix store and binary cache,

  - nix store add-path # NOT add-file, different hashing scheme
  - cachix push chezbryan
  - cachix pin chezbryan pulsar-source
  - nix store make-content-addressed # check that hash is _not_ changed

  See also: https://github.com/NixOS/nix/issues/6210#issuecomment-1060834892

  The store path can then be reused:

  ```nix
    let
      path = /nix/store/rvvbgyfk49axxlgvd9hxgi1jgkppanv6-Linux.pulsar-1.119.0.tar.gz;
    in
    builtins.fetchClosure {
      fromStore = "https://chezbryan.cachix.org";
      # it seems that cachix doesn't advertise ca-derivations;
      # no worries, just treat them as input addressed:
      toPath = path;
      fromPath = path;
    };
  ```

  Alternatively, if GITHUB_TOKEN is properly configured, we may automate this
  whole process with `fetchzip` as follows:
*/

let

  /** id of the linux artifact from the github action,
      obtained from the download link through the web ui */
  artifact_id = "1818489884";
  hash = "sha256-tXjjAE1vVj4UrAHKVsRftNBJlJuF5L3hB9KzEM7hxBM=";

in

pulsar.overrideAttrs (final: prev: {
  version = "1.120.0";
  src = (fetchzip {

    url = "https://api.github.com/repos/pulsar-edit/pulsar/actions/artifacts/${artifact_id}/zip";
    extension = "zip";
    stripRoot = false;

    /** pick out the `.tar.gz` file */
    postFetch = ''
      mv "$out" "$unpackDir"
      mv "$unpackDir"/*.tar.gz "$out"
    '';
    name = "Linux.pulsar-${final.version}.tar.gz";
    inherit hash;

    /**
      `netrcImpureEnvVars` is appended to the usual `impureEnvVars`.
      We still need to correctly pass in the environment variables. Note
      that for a multi-user setup, this must happen on the nix-daemon side,
      which is probably started as a systemd service, so one needs to
      correctly patch the service definitions.
      
      Alternatively, we may use the `configurable-impure-env` experimental
      feature, which can be fully specified in `/etc/nix/nix.conf`:

      ```conf
        extra-experimental-features = configurable-impure-env
        impure-env = GITHUB_TOKEN=${{ secrets.GITHUB_TOKEN }}
        trusted-users = root runner @wheel
      ```

      This is implemented in: ../.github/workflows/build.yml
    */
    netrcImpureEnvVars = ["GITHUB_TOKEN"];
  }).overrideAttrs ({ postFetch, ... }: {
    /**
      `postHook` is a seemingly undocumented hook executed at the end of
      `setupPhase`, as implemented in `setup.sh`. This happens before the
      actual build process. Here we use it to pass in the actual token.

      We cannot supply `curlOptsList` in nix, as it would be over-escaped
      and the `$GITHUB_TOKEN` would not be correctly expanded.
      */
    postHook = ''
      curlOptsList="'--header' 'Authorization: Bearer $GITHUB_TOKEN'"
    '';

    /**
      `postFetch` of `fetchurl` is augmented by `fetchzip`. We patch the
      final version again to remove the unnecessary executable bits.
    */
    postFetch = postFetch + ''
      chmod 644 "$out"
    '';
  });
})
