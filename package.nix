{
  lib,
  stdenvNoCC,
  fetchurl,
  autoPatchelfHook,
  versionCheckHook,
}:
let
  version = "1.5.16";

  platformMap = {
    x86_64-linux = "linux_x64";
    aarch64-linux = "linux_arm64";
    x86_64-darwin = "mac_x64";
    aarch64-darwin = "mac_arm64";
  };

  hashes = {
    x86_64-linux = "sha256-m9qyNNBrrRphviMhByZS6wa+eLr/Gsv65HMx2loJCrw=";
    aarch64-linux = "sha256-fd7seQCE5VCvGK2wSltsX98ts+ECaFT0mQGgTLQmXH4=";
    x86_64-darwin = "sha256-FM12ox5CrUYdb4rfdjEwbKw3VT9UeroKDxEbCCTSHAw=";
    aarch64-darwin = "sha256-ukcgL3Et5MSnj9eH2BuiBtc+Ecl1cvxpQg8pp378jZU=";
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
