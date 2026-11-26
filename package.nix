{
  lib,
  stdenvNoCC,
  fetchurl,
  autoPatchelfHook,
  versionCheckHook,
}:
let
  version = "1.5.18";

  platformMap = {
    x86_64-linux = "linux_x64";
    aarch64-linux = "linux_arm64";
    x86_64-darwin = "mac_x64";
    aarch64-darwin = "mac_arm64";
  };

  hashes = {
    x86_64-linux = "sha256-pJYHI+2c9bWscu1UHbjfTWJ0F5UmHrk6RoEAbMsj1a0=";
    aarch64-linux = "sha256-l3mauskboLKbd1mLYvkDuGZGHaF2gCY6GC/vLLeWqw0=";
    x86_64-darwin = "sha256-ET4FjfjD5IjJD2Trsdvfd2PKAa9wJ+z9c64YnzxTA2Y=";
    aarch64-darwin = "sha256-8VT9voGIXDZWW3RhWp72x8kvucK8KaywowC8WZBpGHE=";
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
