{
  lib,
  rustPlatform,
  fetchFromGitHub,
}:

rustPlatform.buildRustPackage rec {
  pname = "open-webui-cli";
  version = "0.1.2";

  src = fetchFromGitHub {
    owner = "mitchty";
    repo = "open-webui-cli";
    rev = "v${version}";
    hash = "sha256-X84TpRBlF56gjdrWFbL69xLOx8s4XpM0RedzhGCvAI4=";
  };

  useFetchCargoVendor = true;
  cargoHash = "sha256-HhBMs8t7SBKzwMmCIoUL4B14W/4jUpgs3J/InNiR9FM=";

  meta = {
    description = "Use open-webui via its api from the commandline instead of a browser";
    homepage = "https://github.com/mitchty/open-webui-cli";
    changelog = "https://github.com/mitchty/open-webui-cli/blob/${src.rev}/changelog.md";
    license = lib.licenses.blueOak100;
    maintainers = with lib.maintainers; [ bryangp ];
    mainProgram = "open-webui-cli";
  };
}
