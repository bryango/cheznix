{ runCommand }:

{
  ## link the entire host `/usr` in a package
  host-usr = runCommand "host-usr" { } ''
    ln -s -T /usr $out
  '';


  ## link glibc locales from the system
  host-locales = let

    lib-path = "lib/locale";
    share-path = "share/i18n";
    archive = "locale-archive";

  in runCommand "host-locales" { } ''
    mkdir -p $out/${lib-path}
    ln -s {/usr,$out}/${lib-path}/${archive}

    mkdir -p $out/${share-path}
    ln -s {/usr,$out}/${share-path}/SUPPORTED

    mkdir -p $out/nix-support
    echo "export LOCALE_ARCHIVE=/usr/${lib-path}/${archive}" \
      > $out/nix-support/setup-hook
  '';

}
