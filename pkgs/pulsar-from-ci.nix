/** pulsar from ci builds, instead of github releases */
{ pulsar }:

pulsar.overrideAttrs {
  version = "1.117.0";
  src =
    let
      /**
        Pulsar follows a semi-automated release process. Look under github
        actions for the [artifact] corresponding to the release [commit].
      
        [artifact]: https://github.com/pulsar-edit/pulsar/actions/runs/9106691239
        [commit]: https://github.com/pulsar-edit/pulsar/tree/v1.117.0

        - nix store add-path # NOT add-file, different hashing scheme
        - cachix push chezbryan
        - cachix pin chezbryan pulsar-source
        - nix store make-content-addressed # check that hash is _not_ changed

        See also: https://github.com/NixOS/nix/issues/6210#issuecomment-1060834892
      */
      path = /nix/store/rv5h2cj013782zhqs7qrd5ad0kaf7r6d-Linux.pulsar-1.117.0.tar.gz;
    in
    builtins.fetchClosure {
      fromStore = "https://chezbryan.cachix.org";
      /** it seems that cachix doesn't advertise ca-derivations;
              no worries, just treat them as input addressed: */
      toPath = path;
      fromPath = path;
    };
}
