final: prev: {

  ## do NOT overlay `nix`, otherwise issues may propagate!

  ## bootstrap system-manager incremental builds
  system-manager-artifacts =
    let
      inherit (final.cheznix.inputs) last-gen;
      lastgenPkgs = last-gen.legacyPackages.${prev.system};
      inherit (lastgenPkgs)
        system-manager
        checkpointBuildTools
        ;
    in
      system-manager.passthru.checkpointArtifacts or (
        checkpointBuildTools.prepareCheckpointBuild system-manager
      );

  ## this system-manager is not wrapped with nix
  system-manager =
    let
      checkpointArtifacts = final.system-manager-artifacts;
    in
    ## provide artifacts for the future
    final.addCheckpointArtifacts (
      prev.checkpointBuildTools.mkCheckpointBuild
        final.system-manager-unwrapped
        checkpointArtifacts
    )
  ;

  neovim = prev.neovim.override { withRuby = false; };

  nix-tree = prev.haskell.lib.overrideSrc prev.nix-tree {
    src = prev.fetchFromGitHub {
      owner = "bryango";
      repo = "nix-tree";
      rev = "nix-store-option";
      hash = "sha256-pu3VC4pJ3wDjKXM/Zh0Ae+zGW186vQtYMhIAGRlFKgY=";
    };
  };

  gimp-with-plugins = with prev; gimp-with-plugins.override {
    plugins = with gimpPlugins; [ resynthesizer ];
  };

  redshift = prev.redshift.override {
    withGeolocation = false;
  };

  ## override home environments
  buildEnv = attrs:
    if attrs.name or "" == "home-manager-path"
    then
      (prev.buildEnv attrs).overrideAttrs
        (
          finalAttrs: prevAttrs: {

            ## blacklist glibcLocales
            disallowedRequisites = [ final.glibcLocales ] ++ (
              prevAttrs.disallowedRequisites or [ ]
            );

          }
        )
    else prev.buildEnv attrs;

  # chezmoi = final.callPackage ./chezmoi.nix {
  #   inherit (prev) chezmoi;
  # };

}
