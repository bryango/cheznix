final: prev: {

  ## do NOT overlay `nix`, otherwise issues may propagate!

  ## bootstrap system-manager incremental builds
  system-manager-artifacts =
    let
      # previous successful build
      rev = "57c8c049c2b6d642befdf705b2b2f14b018963c3";
    in
    prev.prepareCheckpointBuild (builtins.getFlake
      "git+file:./?rev=${rev}"
    ).legacyPackages.x86_64-linux.system-manager;

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
