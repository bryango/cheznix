{ nixosModulesPath, ... }:

{
  imports = [
    (nixosModulesPath + "/programs/zsh/zsh.nix")
  ];
}
