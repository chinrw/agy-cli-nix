# agy-cli-nix

Nix flake for [Google Antigravity CLI](https://github.com/google-antigravity/antigravity-cli) (`agy`), tracking upstream GitHub releases on an hourly schedule. It packages the prebuilt binary for `x86_64-linux`, `aarch64-linux`, `x86_64-darwin`, and `aarch64-darwin`, patching ELF binaries with `autoPatchelfHook` and verifying the binary with `versionCheckHook` during builds.

## Quick start

Run `agy` directly without installing it:

```sh
nix run github:chinrw/agy-cli-nix -- --version
```

Install into your user profile:

```sh
nix profile add github:chinrw/agy-cli-nix
```

## Using with Nix flakes

Add `agy-cli-nix` to your `flake.nix` inputs:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    agy-cli-nix = {
      url = "github:chinrw/agy-cli-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
}
```

Reference `inputs.agy-cli-nix.packages.${pkgs.stdenv.hostPlatform.system}.default` (or `.antigravity-cli` / `.agy`) in `environment.systemPackages` or `home.packages`, or apply `inputs.agy-cli-nix.overlays.default` to expose `pkgs.antigravity-cli`.

Because Google distributes Antigravity CLI under an unfree license, consuming flakes that build `pkgs.antigravity-cli` through the overlay need unfree packages permitted for `antigravity-cli` (the flake's own `packages` output already sets `allowUnfreePredicate` for it).

## Updates

### Automated updates

`.github/workflows/update.yml` checks `google-antigravity/antigravity-cli` releases every hour at minute 37 UTC. When a new tag appears, it runs `scripts/update.sh`, opens a pull request against `main` using `UPDATE_TOKEN`, and enables squash auto-merge once Linux and macOS CI checks pass. See [Repository settings](.github/REPOSITORY_SETTINGS.md) for the required token and branch ruleset setup.

### Manual updates

Check whether a newer upstream release is available:

```sh
./scripts/update.sh --check
```

Update `package.nix` and `flake.lock` to the latest release (or pass `--version` for a specific tag):

```sh
./scripts/update.sh
./scripts/update.sh --version 1.5.14
```

## Development checks

Run formatting, workflow linting, unit tests, and flake build checks:

```sh
nix develop -c nixfmt --check flake.nix package.nix
nix develop -c actionlint
nix develop -c python3 -m unittest discover -s tests -v
nix flake check --print-build-logs
nix build .#antigravity-cli --print-build-logs
./result/bin/agy --version
```

## License

The Nix expressions, scripts, and workflows in this repository are licensed under the MIT License; see [LICENSE](LICENSE). Google Antigravity CLI itself is unfree software distributed by Google.
