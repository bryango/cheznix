final: prev: {

  ## do NOT overlay `nix`, otherwise issues may propagate!

  ## bootstrap system-manager incremental builds
  system-manager-artifacts =
    let
      inherit (final.cheznix.inputs) last-gen;
      inherit (last-gen.legacyPackages.${prev.system})
        system-manager-unwrapped;
    in
    ## if last-gen is built with `addCheckpointArtifacts`, this would be cached
    prev.checkpointBuildTools.prepareCheckpointBuild system-manager-unwrapped;
    ## ... do _not_ use `passthru.checkpointArtifacts` directly,
    ## ... unless last-gen is _certainly_ built with `addCheckpointArtifacts`.
    ## ... otherwise this would be a bootstrap problem.

  ## this system-manager is not wrapped with nix
  system-manager =
    let
      inherit (prev) mktemp rsync;
      checkpointArtifacts = final.system-manager-artifacts;
    in
    ## provide artifacts for the future
    final.addCheckpointArtifacts
      (final.system-manager-unwrapped.overrideAttrs (prevAttrs: {
        preBuild = (prevAttrs.preBuild or "") + ''
          set -e

          ## handle removed files:
          sourcePatch=$(${mktemp}/bin/mktemp)
          diff -ur ${checkpointArtifacts}/sources ./ > "$sourcePatch" || true

          ## handle binaries:
          newSourceBackup=$(${mktemp}/bin/mktemp -d)
          shopt -s dotglob
          mv ./* "$newSourceBackup"

          ## clean up, do not panic when there is nothing left (expected)
          rm -r * || true

          ## layer 0: artifacts
          ${rsync}/bin/rsync \
            --checksum --times --atimes --chown=$USER:$USER --chmod=+w \
            -r ${checkpointArtifacts}/outputs/ .

          ## layer 1: handle removed files: patch source texts
          patch -p 1 -i "$sourcePatch" || true
          ## ... do not panic when its unsuccessful (remedied immediately)

          ## layer 2: handle binaries: overlay the new source
          ${rsync}/bin/rsync \
            --checksum --times --atimes --chown=$USER:$USER --chmod=+w \
            -r "$newSourceBackup"/ .

          ## clean up
          rm "$sourcePatch"
          rm -rf "$newSourceBackup"
        '';
      }))
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
