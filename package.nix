{
  lib,
  stdenvNoCC,
  fetchurl,
  autoPatchelfHook,
  versionCheckHook,
}:
let
  version = "1.5.15";

  platformMap = {
    x86_64-linux = "linux_x64";
    aarch64-linux = "linux_arm64";
    x86_64-darwin = "mac_x64";
    aarch64-darwin = "mac_arm64";
  };

  hashes = {
    x86_64-linux = "sha256-jZkTKYYCBJ7ynpZp81JStreVcZec4b0PsndTx7rIQRQ=";
    aarch64-linux = "sha256-5bXXyh3aLP3AsJxykxMgw+9cSBoU29oTcwQQfObndrE=";
    x86_64-darwin = "sha256-kf7gQ6OEt2zuXV8VaLlGqy8lvzjJOPC9fEsn/voMTkM=";
    aarch64-darwin = "sha256-niUQjz6nDMbIRtiLk5dFbROuRyoBABbD1iXrP+ma/Do=";
  };

  system = stdenvNoCC.hostPlatform.system;
  platform = platformMap.${system} or (throw "Unsupported system: ${system}");
in
stdenvNoCC.mkDerivation {
  pname = "antigravity-cli";
  inherit version;

  strictDeps = true;
  __structuredAttrs = true;

  src = fetchurl {
    url = "https://github.com/google-antigravity/antigravity-cli/releases/download/${version}/agy_cli_${platform}.tar.gz";
    hash = hashes.${system};
  };

  sourceRoot = ".";

  nativeBuildInputs = lib.optionals stdenvNoCC.hostPlatform.isElf [ autoPatchelfHook ];

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    install -Dm755 antigravity $out/bin/agy

    runHook postInstall
  '';

  nativeInstallCheckInputs = [ versionCheckHook ];
  doInstallCheck = true;

  meta = {
    description = "Google's Go-based terminal user interface (TUI) agent client";
    homepage = "https://antigravity.google";
    changelog = "https://github.com/google-antigravity/antigravity-cli/releases";
    license = lib.licenses.unfree;
    platforms = lib.attrNames platformMap;
    mainProgram = "agy";
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
}
