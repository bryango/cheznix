final: prev: with prev; {

  ## do NOT overlay `nix`, otherwise issues may propagate!

  home-manager = home-manager.override {
    ## option inspection does not work for flakes
    ## so simply drop this dependency to save space
    nixos-option = null;
  };

  v2ray = runCommand "${v2ray.name}-rewrapped"
    {
      nativeBuildInputs = [ buildPackages.makeBinaryWrapper ];
    }
    ''
      mkdir -p $out/bin
      cd $out/bin
      makeBinaryWrapper \
        "${final.undoWrapProgram v2ray}/bin/v2ray" \
        "$out/bin/v2ray" \
        --inherit-argv0 \
        --suffix XDG_DATA_DIRS : "${v2ray.assetsDrv}/share"
    '';

  neovim = neovim.override { withRuby = false; };

  gimp-with-plugins = gimp-with-plugins.override {
    plugins = with gimpPlugins; [ resynthesizer ];
  };

  redshift-vanilla = (redshift.override {
    withGeolocation = false;
    withAppIndicator = false;
  }).overrideAttrs {
    postFixup = ''
      wrapPythonPrograms
      makeBinaryWrapper \
        "$out/bin/redshift" \
        "$out/bin/.redshift-rewrapped" \
        --inherit-argv0 \
        "''${gappsWrapperArgs[@]}"
    '';
  };

  redshift = let redshift = final.redshift-vanilla; in
    symlinkJoin {
      name = "${redshift.name}-rewrapped";
      paths = [ redshift ];
      postBuild = ''
        cd $out/bin
        rm redshift
        mv .redshift-rewrapped redshift
      '';
    };

  ## override home environments
  buildEnv = attrs:
    if attrs.name or "" != "home-manager-path"
    then buildEnv attrs
    else
      (buildEnv attrs).overrideAttrs (prevAttrs: {

        ## blacklist glibcLocales
        disallowedRequisites = [ final.glibcLocales ] ++ (
          prevAttrs.disallowedRequisites or [ ]
        );

      });

  # chezmoi = final.callPackage ./chezmoi.nix {
  #   inherit (prev) chezmoi;
  # };

}
