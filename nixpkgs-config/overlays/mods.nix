final: prev:

with prev;

{
  ## be careful of `rec`, might not work

  ## inherit to trigger ci builds
  inherit
    # gitbutler
    # hydra-check
    tectonic
    texpresso
    python2
    code-cursor
  ;

  /** nix package used for the `nix.package` configuration */
  nixPackage = (nixVersions.latest.appendPatches [
    (fetchpatch2 {
      name = "fix-zsh-completions.patch";
      url = "https://github.com/NixOS/nix/commit/f434a3e3c637fcfd371e62f6167ac9bc136e012e.patch?full_index=1";
      hash = "sha256-bBH9e4Eg6viEM7PlKGK4OrKFVzXt/80w/koZbAZmslE=";
    })
    (fetchpatch2 {
      name = "fix-darwin-ld-versioning.patch";
      url = "https://github.com/NixOS/nix/commit/a24df3d4e5ba03570294abfb49660b5258337484.patch?full_index=1";
      hash = "sha256-LBlDXe7WMlCQFZF/SotBp0vLK24VNtoTS2l+Xct0dP0=";
    })
  ]);
  # nixPackage = lixPackageSets.latest.lix;
  # nixPackage = nixVersions.stable.overrideAttrs ({ patches ? [  ], ... }: {
  #   patches = patches ++ [
  #   ];
  # });

  # many flaky tests
  tailscale = tailscale.overrideAttrs {
    # doCheck = false;
  };

  nixpkgs-pr-checker = callPackage ../pkgs/nixpkgs-pr-checker.nix { };
  open-webui-cli = callPackage ../pkgs/open-webui-cli.nix { };

  texstudio-lazy_resize = texstudio.overrideAttrs ({ patches ? [ ], ... }: {
    pname = "texstudio-lazy_resize";
    patches = patches ++ [
      (fetchpatch2 {
        name = "do-not-resize-pdf-after-rebuilds.patch";
        url = "https://github.com/texstudio-org/texstudio/compare/master...bryango:master.patch";
        hash = "sha256-KN2oTeNljgYjbvta96uwZnKUFZu+6IIUBIaNwIcGwvw=";
      })
    ];
  });

  git-master = lib.dontDistribute (git.overrideAttrs ({ nativeBuildInputs ? [ ], preAutoreconf ? "", meta ? { }, ... }: {
    version = "2.46.0-unstable-2024-07-29";
    src = fetchFromGitHub {
      owner = "git";
      repo = "git";
      rev = "ad57f148c6b5f8735b62238dda8f571c582e0e54";
      hash = "sha256-CeC3YnFMNE9bmb3f0NGEH0gdioTtMfdLfYAhi63tWdc=";
    };
    nativeBuildInputs = nativeBuildInputs ++ [ autoreconfHook ];
    preAutoreconf = preAutoreconf + ''
      make configure # run autoconf to generate ./configure from master
    '';
  }));

  pulsar = callPackage ../pkgs/pulsar-from-ci.nix { inherit pulsar; };

  # we do not need kcm support on e.g. gnome
  fcitx5-configtool-no-kcm = kdePackages.fcitx5-configtool.override {
    kcmSupport = false;
  };

  byobu-with-tmux = symlinkJoin {
    name = "byobu-with-tmux-${byobu.version}";
    paths = [
      tmux
      tmux.man
      (byobu.override {
        screen = null;
        vim = null;
      })
    ];
    meta = (byobu.meta or { }) // {
      description = "Byobu with only the Tmux backend";
    };
  };

}
