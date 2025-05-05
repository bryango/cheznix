{ fetchurl
, glib
, gtk3
, lib
, libdrm
, libgcrypt
, libkrb5
, libnotify
, mesa # for libgbm
, libGL
, nss
, systemd
, stdenv
, vips
, autoPatchelfHook
, wrapGAppsHook
, webkitgtk
, libappindicator-gtk3
, python3
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "nutstore";
  version = "6.2.8";

  src = fetchurl {
    url = "https://pkg-cdn.jianguoyun.com/static/exe/ex/${finalAttrs.version}/nutstore_client-${finalAttrs.version}-linux-x86_64-public.tar.gz";
    hash = lib.fakeHash;
  };

  nativeBuildInputs = [
    autoPatchelfHook
    wrapGAppsHook
  ];

  buildInputs = [
    glib
    gtk3
    libdrm
    libgcrypt
    libkrb5
    mesa
    nss
    vips
    webkitgtk
    libappindicator-gtk3
    libnotify
  ];

  propagatedBuildInputs = [
    (python3.withPackages (pyPkgs: with pyPkgs; [
      pyobject3
    ]))
  ];

  runtimeDependencies = map lib.getLib [
    systemd
  ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin
    cp -r opt $out/opt
    cp -r usr/share $out/share
    substituteInPlace $out/share/applications/qq.desktop \
      --replace "/opt/QQ/qq" "$out/bin/qq" \
      --replace "/usr/share" "$out/share"
    makeWrapper $out/opt/QQ/qq $out/bin/qq \
      --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath [ libGL ]}" \
      --add-flags "\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+--ozone-platform-hint=auto --enable-features=WaylandWindowDecorations}}"

    # Remove bundled libraries
    rm -r $out/opt/QQ/resources/app/sharp-lib

    # https://aur.archlinux.org/cgit/aur.git/commit/?h=linuxqq&id=f7644776ee62fa20e5eb30d0b1ba832513c77793
    rm -r $out/opt/QQ/resources/app/libssh2.so.1

    runHook postInstall
  '';

  passthru.updateScript = ./update.sh;

  meta = with lib; {
    homepage = "https://www.jianguoyun.com";
    description = "A cloud service that lets you sync and share files";
    platforms = [ "x86_64-linux" ];
    license = licenses.unfree;
    sourceProvenance = with sourceTypes; [ binaryNativeCode ];
    maintainers = with lib.maintainers; [ bryango ];
  };
})
