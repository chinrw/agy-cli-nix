#!/usr/bin/env bash
set -euo pipefail

readonly GITHUB_REPO="google-antigravity/antigravity-cli"
readonly RELEASE_BASE="https://github.com/${GITHUB_REPO}/releases/download"

readonly SYSTEMS=(
  "x86_64-linux:linux_x64"
  "aarch64-linux:linux_arm64"
  "x86_64-darwin:mac_x64"
  "aarch64-darwin:mac_arm64"
)

log_info() { printf '[INFO] %s\n' "$1"; }
log_error() { printf '[ERROR] %s\n' "$1" >&2; }

print_usage() {
  cat <<EOF
Usage: $0 [OPTIONS]

Options:
  --version VERSION  Update to a specific release version
  --check            Check whether a newer release is available without modifying files
  --help             Show this help message
EOF
}

get_current_version() {
  sed -n 's/^[[:space:]]*version = "\([^"]*\)";/\1/p' package.nix | head -1
}

get_latest_version() {
  local tag
  tag=$(gh release view --repo "$GITHUB_REPO" --json tagName -q '.tagName' 2>/dev/null || true)
  if [ -z "$tag" ]; then
    log_error "Failed to fetch latest release tag from GitHub"
    exit 1
  fi
  printf '%s\n' "${tag#v}"
}

fetch_sri_hash() {
  local version="$1"
  local platform="$2"
  local url="${RELEASE_BASE}/${version}/agy_cli_${platform}.tar.gz"
  local hash

  hash=$(nix store prefetch-file --json --hash-type sha256 "$url" 2>/dev/null | jq -r '.hash // empty' || true)
  if [ -z "$hash" ] || [ "$hash" = "null" ]; then
    return 1
  fi
  printf '%s\n' "$hash"
}

rewrite_package_nix() {
  local src="$1"
  local dst="$2"
  local new_version="$3"
  shift 3

  # Apply version first, then replace each system entry inside `hashes = { ... };`.
  awk -v version="$new_version" '
    !version_done && /^[[:space:]]*version = "[^"]*";/ {
      sub(/"[^"]*"/, "\"" version "\"")
      version_done=1
    }
    { print }
  ' "$src" > "$dst"

  local entry system hash tmp_step
  for entry in "$@"; do
    system="${entry%%=*}"
    hash="${entry#*=}"
    tmp_step=$(mktemp)
    awk -v target_system="$system" -v hash="$hash" '
      /^[[:space:]]*hashes = \{/ { in_hashes=1 }
      in_hashes && $0 ~ "^[[:space:]]*" target_system "[[:space:]]*=" {
        sub(/= "[^"]*";/, "= \"" hash "\";")
      }
      in_hashes && /^[[:space:]]*\};/ { in_hashes=0 }
      { print }
    ' "$dst" > "$tmp_step"
    mv "$tmp_step" "$dst"
  done
}

ensure_required_tools() {
  local tool
  for tool in nix jq awk sed; do
    if ! command -v "$tool" >/dev/null 2>&1; then
      log_error "Required command not found: $tool"
      exit 1
    fi
  done
}

main() {
  local repo_root
  repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
  cd "$repo_root"

  if [ ! -f "flake.nix" ] || [ ! -f "package.nix" ]; then
    log_error "flake.nix or package.nix not found in $repo_root"
    exit 1
  fi

  local target_version=""
  local check_only=false

  while [ "$#" -gt 0 ]; do
    case "$1" in
      --version)
        if [ "$#" -lt 2 ] || [ -z "${2:-}" ]; then
          log_error "--version requires a value"
          exit 1
        fi
        target_version="${2#v}"
        shift 2
        ;;
      --check)
        check_only=true
        shift
        ;;
      --help)
        print_usage
        exit 0
        ;;
      *)
        log_error "Unknown option: $1"
        print_usage >&2
        exit 1
        ;;
    esac
  done

  ensure_required_tools
  if [ -z "$target_version" ] && ! command -v gh >/dev/null 2>&1; then
    log_error "Required command not found: gh"
    exit 1
  fi

  local current_version
  current_version=$(get_current_version)
  if [ -z "$current_version" ]; then
    log_error "Could not read current version from package.nix"
    exit 1
  fi

  local latest_version
  if [ -n "$target_version" ]; then
    latest_version="$target_version"
  else
    latest_version=$(get_latest_version)
  fi

  log_info "Current version: $current_version"
  log_info "Latest version: $latest_version"

  if [ "$current_version" = "$latest_version" ]; then
    log_info "Already up to date"
    exit 0
  fi

  if [ "$check_only" = true ]; then
    log_info "Update available: $current_version -> $latest_version"
    exit 1
  fi

  local staged_package backup_package
  staged_package=$(mktemp)
  backup_package=$(mktemp)
  trap 'rm -f "${staged_package:-}" "${backup_package:-}"' EXIT

  local hash_pairs=()
  local pair system platform hash
  for pair in "${SYSTEMS[@]}"; do
    system="${pair%%:*}"
    platform="${pair#*:}"
    log_info "Fetching hash for $system ($platform)"
    if ! hash=$(fetch_sri_hash "$latest_version" "$platform"); then
      log_error "Failed to fetch hash for $system ($platform)"
      exit 1
    fi
    log_info "Resolved $system: $hash"
    hash_pairs+=("${system}=${hash}")
  done

  cp package.nix "$backup_package"
  rewrite_package_nix package.nix "$staged_package" "$latest_version" "${hash_pairs[@]}"
  mv "$staged_package" package.nix

  log_info "Verifying build for .#antigravity-cli"
  if ! nix build .#antigravity-cli --no-link >/dev/null 2>&1; then
    log_error "Build verification failed; restoring previous package.nix"
    mv "$backup_package" package.nix
    exit 1
  fi

  rm -f "$backup_package"
  log_info "Updating flake.lock"
  nix flake update

  log_info "Updated antigravity-cli from $current_version to $latest_version"
}

main "$@"
