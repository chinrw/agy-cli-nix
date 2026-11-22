{
  description = "Nix flake for Google Antigravity CLI (agy)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  };

  outputs =
    { self, nixpkgs }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      eachSystem = nixpkgs.lib.genAttrs systems;

      overlay = final: _prev: {
        antigravity-cli = final.callPackage ./package.nix { };
      };

      pkgsFor =
        system:
        import nixpkgs {
          inherit system;
          config.allowUnfreePredicate = pkg: builtins.elem (nixpkgs.lib.getName pkg) [ "antigravity-cli" ];
          overlays = [ overlay ];
        };
    in
    {
      packages = eachSystem (
        system:
        let
          pkgs = pkgsFor system;
        in
        {
          default = pkgs.antigravity-cli;
          antigravity-cli = pkgs.antigravity-cli;
          agy = pkgs.antigravity-cli;
        }
      );

      apps = eachSystem (
        system:
        let
          pkgs = pkgsFor system;
          app = {
            type = "app";
            program = "${pkgs.antigravity-cli}/bin/agy";
          };
        in
        {
          default = app;
          agy = app;
          antigravity-cli = app;
        }
      );

      overlays.default = overlay;

      checks = eachSystem (
        system:
        let
          pkgs = pkgsFor system;
        in
        {
          antigravity-cli = pkgs.antigravity-cli;
          updater =
            pkgs.runCommand "antigravity-cli-updater-tests"
              {
                nativeBuildInputs = with pkgs; [
                  python3
                  bash
                  gnused
                  gawk
                  coreutils
                  jq
                ];
              }
              ''
                cp ${./flake.nix} flake.nix
                cp ${./package.nix} package.nix
                cp -r ${./scripts} scripts
                cp -r ${./tests} tests
                chmod +x scripts/update.sh
                export PYTHONDONTWRITEBYTECODE=1
                python3 -m unittest discover -s tests -v
                touch "$out"
              '';
        }
      );

      formatter = eachSystem (system: (import nixpkgs { inherit system; }).nixfmt-tree);

      devShells = eachSystem (
        system:
        let
          pkgs = pkgsFor system;
        in
        {
          default = pkgs.mkShell {
            packages = with pkgs; [
              nixfmt
              gh
              jq
              curl
              python3
              actionlint
            ];
          };
        }
      );
    };
}
