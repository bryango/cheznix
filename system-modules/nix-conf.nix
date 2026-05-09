{
  nix.enable = true;
  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
      "fetch-closure"
    ];
    build-users-group = "nixbld";
    trusted-users = [ "@wheel" ];
    extra-substituters = [
      ## with `?priority`
      "https://mirrors.tuna.tsinghua.edu.cn/nix-channels/store?priority=20"
      # "https://mirror.sjtu.edu.cn/nix-channels/store?priority=20"

      ## cachix use <cache> -O .
      "https://chezbryan.cachix.org"
      "https://nix-community.cachix.org"
    ];
    extra-trusted-public-keys = [
      "chezbryan.cachix.org-1:4n1STyrAtSfRth4sbgUCKfgjtgR8yIy40jIV829Lfow="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    ];
  };
}
