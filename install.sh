#!/usr/bin/env bash
# shellcheck disable=SC2155
# shellcheck disable=SC2164

# Helper function for regex matching (Bash 3.0+ compatible)
function regex_match() {
  [[ $1 =~ $2 ]]
}

function is_git_installed() {
  command -v git >/dev/null 2>&1
}

function compute_sha256() {
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | awk '{print $1}'
  elif command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    echo ""
  fi
}

# Verify the downloaded 'bashunit' file against the release 'checksum' asset.
# Arguments: $1 - the bashunit download URL. Exits 1 (and removes the binary)
# on any failure so a tampered or unverifiable download never looks successful.
function verify_checksum() {
  local url=$1
  local checksum_url="${url%/bashunit}/checksum"

  local expected
  if command -v curl >/dev/null 2>&1; then
    expected=$(curl -fsSL --retry 3 --retry-delay 2 "$checksum_url" 2>/dev/null | awk '{print $1}')
  else
    expected=$(wget -qO- "$checksum_url" 2>/dev/null | awk '{print $1}')
  fi

  if [ -z "$expected" ]; then
    echo "Error: could not download checksum from $checksum_url" >&2
    rm -f bashunit
    exit 1
  fi

  local actual
  actual=$(compute_sha256 bashunit)
  if [ -z "$actual" ]; then
    echo "Error: no sha256 tool (shasum/sha256sum) available to verify checksum" >&2
    rm -f bashunit
    exit 1
  fi

  if [ "$actual" != "$expected" ]; then
    echo "Error: checksum mismatch for bashunit '$TAG'" >&2
    echo "  expected: $expected" >&2
    echo "  actual:   $actual" >&2
    rm -f bashunit
    exit 1
  fi

  echo "> Checksum verified ($actual)"
}

function build_and_install_beta() {
  echo "> Downloading non-stable version: 'beta'"

  if ! is_git_installed; then
    echo "Error: git is not installed." >&2
    exit 1
  fi

  git clone --depth 1 --no-tags "$BASHUNIT_GIT_REPO" temp_bashunit 2>/dev/null
  cd temp_bashunit
  ./build.sh bin >/dev/null
  local latest_commit=$(git rev-parse --short=7 HEAD)
  # shellcheck disable=SC2103
  cd ..

  local beta_version=$(printf "(non-stable) beta after %s [%s] 🐍 #%s" \
    "$LATEST_BASHUNIT_VERSION" \
    "$(date +'%Y-%m-%d')" \
    "$latest_commit")

  sed -i -e 's/BASHUNIT_VERSION=".*"/BASHUNIT_VERSION="'"$beta_version"'"/g' temp_bashunit/bin/bashunit
  cp temp_bashunit/bin/bashunit ./
  rm -rf temp_bashunit
}

function install() {
  if [[ $VERSION != 'latest' ]]; then
    TAG="$VERSION"
    echo "> Downloading a concrete version: '$TAG'"
  else
    echo "> Downloading the latest version: '$TAG'"
  fi

  local url="$BASHUNIT_GIT_REPO/releases/download/$TAG/bashunit"
  if command -v curl >/dev/null 2>&1; then
    curl -fL --retry 3 --retry-delay 2 -O -J "$url" 2>/dev/null
  elif command -v wget >/dev/null 2>&1; then
    wget --tries=3 "$url" 2>/dev/null || wget "$url" 2>/dev/null
  else
    echo "Cannot download bashunit: curl or wget not found." >&2
    exit 1
  fi

  if [ ! -f "bashunit" ]; then
    echo "Error: failed to download bashunit '$TAG' from $url" >&2
    exit 1
  fi

  if [ "${BASHUNIT_VERIFY_CHECKSUM:-false}" = "true" ]; then
    verify_checksum "$url"
  fi

  chmod u+x "bashunit"
}

#########################
######### MAIN ##########
#########################

# Defaults
DIR="lib"
VERSION="latest"

function is_version() {
  regex_match "$1" '^[0-9]+\.[0-9]+\.[0-9]+$' || [[ "$1" == "latest" || "$1" == "beta" ]]
}

# Parse arguments flexibly
if [[ $# -eq 1 ]]; then
  if is_version "$1"; then
    VERSION="$1"
  else
    DIR="$1"
  fi
elif [[ $# -eq 2 ]]; then
  if is_version "$1"; then
    VERSION="$1"
    DIR="$2"
  elif is_version "$2"; then
    DIR="$1"
    VERSION="$2"
  else
    echo "Invalid arguments. Expected version or directory." >&2
    exit 1
  fi
fi

BASHUNIT_GIT_REPO="https://github.com/TypedDevs/bashunit"
LATEST_BASHUNIT_VERSION="0.38.0"
TAG="$LATEST_BASHUNIT_VERSION"

cd "$(dirname "$0")"
rm -f "$DIR"/bashunit
[ -d "$DIR" ] || mkdir -p "$DIR"
cd "$DIR"

if [[ $VERSION == 'beta' ]]; then
  build_and_install_beta
else
  install
fi

echo "> bashunit has been installed in the '$DIR' folder"
