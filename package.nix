{
  lib,
  stdenvNoCC,
  fetchurl,
  autoPatchelfHook,
  versionCheckHook,
}:
let
  version = "1.5.14";

  platformMap = {
    x86_64-linux = "linux_x64";
    aarch64-linux = "linux_arm64";
    x86_64-darwin = "mac_x64";
    aarch64-darwin = "mac_arm64";
  };

  hashes = {
    x86_64-linux = "sha256-1YOGMi0gc+lrM/fMMrTpri22Io9YRANpcllnst5Ix7U=";
    aarch64-linux = "sha256-5faaMSP6xml0swPZogHzgaD7MrPvhp2ROdqF1cr2eio=";
    x86_64-darwin = "sha256-wUIUEUHLqpP05GkEt2NB40nz8reERfh385Ro3+YN2h4=";
    aarch64-darwin = "sha256-sBvdRZHhPd/LDgSb6nSun4PoCCmtz2SqpY9b+xpCWlQ=";
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
