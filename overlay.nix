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
            owner = "bryango";
            repo = "nix-tree";
            rev = "nix-store-option";
            hash = "sha256-pu3VC4pJ3wDjKXM/Zh0Ae+zGW186vQtYMhIAGRlFKgY=";
          };
        }
    else lib.warn "nix-tree updated, overlay skipped" nix-tree;

  gimp-with-plugins = with prev; gimp-with-plugins.override {
    plugins = with gimpPlugins; [ resynthesizer ];
  };

  redshift = prev.redshift.override {
    withGeolocation = false;
  };

  ## override home environments
  buildEnv = attrs:
    if attrs.name or "" != "home-manager-path"
    then prev.buildEnv attrs
    else
      (prev.buildEnv attrs).overrideAttrs (prevAttrs: {

        ## blacklist glibcLocales
        disallowedRequisites = [ final.glibcLocales ] ++ (
          prevAttrs.disallowedRequisites or [ ]
        );

      });

  # chezmoi = final.callPackage ./chezmoi.nix {
  #   inherit (prev) chezmoi;
  # };

}
