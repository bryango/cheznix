{ nixosModulesPath, ... }:

{
  imports = [
    (nixosModulesPath + "/programs/zsh/zsh.nix")
    (nixosModulesPath + "/system/build.nix")
    ./shells-env.nix
  ];
}
