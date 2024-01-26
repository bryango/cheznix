final: prev: {

  ## do NOT overlay `nix`, otherwise issues may propagate!

  neovim = prev.neovim.override { withRuby = false; };

  nix-tree =
    let
      inherit (prev)
        lib
        fetchFromGitHub
        nix-tree
        ;
      targetVersion = "0.4.0";
    in
    if lib.versionOlder (lib.getVersion nix-tree) targetVersion
    then
      prev.haskell.lib.overrideSrc nix-tree
        {
          src = fetchFromGitHub {
            owner = "utdemir";
            repo = "nix-tree";
            rev = "v${targetVersion}";
            hash = "sha256-9D/o4kA/Y7CX3PlaxHl2M6wd5134WaAOphzoZ1tI4Bw=";
          };
        }
    else nix-tree;

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
