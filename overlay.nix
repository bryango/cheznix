final: prev: {

  ## do NOT overlay `nix`, otherwise issues may propagate!

  ## bootstrap system-manager incremental builds
  system-manager-artifacts =
    let
      inherit (final.cheznix.inputs) last-gen;
    in
    prev.checkpointBuildTools.prepareCheckpointBuild
      last-gen.packages.${prev.system}.system-manager-unwrapped;

  ## this system-manager is not wrapped with nix
  system-manager =
    let
      inherit (prev) mktemp rsync;
      checkpointArtifacts = final.system-manager-artifacts;
    in
    final.system-manager-unwrapped.overrideAttrs (prevAttrs: {
      preBuild = (prevAttrs.preBuild or "") + ''
        set -e

        ## move the new source into a backup directory
        newSourceDir=$(${mktemp}/bin/mktemp -d)
        shopt -s dotglob
        mv ./* "$newSourceDir"

        ## ensure that the current directory is empty
        rm -r * || true
        ## ... do not panic when there is nothing left

        ## copy the artifacts into the current directory
        ${rsync}/bin/rsync \
          --checksum --times --atimes --chown=$USER:$USER --chmod=+w \
          -r ${checkpointArtifacts}/outputs/ .

        ## overlay the new source on top of the artifacts
        ${rsync}/bin/rsync \
          --checksum --times --atimes --chown=$USER:$USER --chmod=+w \
          -r "$newSourceDir"/ .
      '';
    })
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
