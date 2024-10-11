#!/bin/bash
# shellcheck disable=SC2155
# shellcheck disable=SC2164
# shellcheck disable=SC2103

function check_git_is_installed() {
  if ! command -v git >/dev/null 2>&1; then
    echo "Error: git is not installed." >&2
    exit 1
  fi
}

function get_latest_tag() {
  git ls-remote --tags "$BASHUNIT_GIT_REPO" |
    awk '{print $2}' |
    sed 's|^refs/tags/||' |
    sort -Vr |
    head -n 1
}

function build_and_install_beta() {
  echo "> Downloading non-stable version: 'beta'"
  git clone --depth 1 --no-tags https://github.com/TypedDevs/bashunit temp_bashunit 2>/dev/null
  cd temp_bashunit
  ./build.sh >/dev/null
  local latest_commit
  latest_commit=$(git rev-parse --short=8 HEAD)
  cd ..

  local beta_version
  beta_version='(non-stable) beta after '"$LATEST_BASHUNIT_VERSION"' ['"$(date +'%Y-%m-%d')"'] 🐍 #'"$latest_commit"

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

  if command -v curl > /dev/null 2>&1; then
    curl -L -O -J "https://github.com/TypedDevs/bashunit/releases/download/$TAG/bashunit" 2>/dev/null
  elif command -v wget > /dev/null 2>&1; then
    wget "https://github.com/TypedDevs/bashunit/releases/download/$TAG/bashunit" 2>/dev/null
  else
    echo "Cannot download bashunit: curl or wget not found."
  fi
  chmod u+x "bashunit"
}

#########################
######### MAIN ##########
#########################

check_git_is_installed

DIR=${1-lib}
VERSION=${2-latest}

BASHUNIT_GIT_REPO="https://github.com/TypedDevs/bashunit"
LATEST_BASHUNIT_VERSION="$(get_latest_tag)"
TAG="$LATEST_BASHUNIT_VERSION"

cd "$(dirname "$0")"
rm -f "$DIR"/bashunit
[ -d "$DIR" ] || mkdir "$DIR"
cd "$DIR"

if [[ $VERSION == 'beta' ]]; then
  build_and_install_beta
else
  install
fi

echo "> bashunit has been installed in the '$DIR' folder"
