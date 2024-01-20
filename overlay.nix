final: prev: {

  ## do NOT overlay `nix`, otherwise issues may propagate!

  ## bootstrap system-manager incremental builds
  system-manager-artifacts =
    let
      # previous successful build
      rev = "ba06b92d12af8e3f1b35358b0eaf745c2ef1eb0e";
    in
    prev.checkpointBuildTools.prepareCheckpointBuild (builtins.getFlake
      "git+file:./?rev=${rev}"
    ).packages.x86_64-linux.system-manager-unwrapped;

  system-manager-vanilla = prev.checkpointBuildTools.mkCheckpointBuild
    final.system-manager-unwrapped
    final.system-manager-artifacts
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
