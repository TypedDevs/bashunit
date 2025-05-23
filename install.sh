#!/usr/bin/env bash
# shellcheck disable=SC2155
# shellcheck disable=SC2164

function is_git_installed() {
  command -v git > /dev/null 2>&1
}

function get_latest_tag() {
  local repository_url=$1

  git ls-remote --tags "$repository_url" |
    awk '{print $2}' |
    sed 's|^refs/tags/||' |
    sort -Vr |
    head -n 1
}

function build_and_install_beta() {
  echo "> Downloading non-stable version: 'beta'"

  if ! is_git_installed; then
    echo "Error: git is not installed." >&2
    exit 1
  fi

  git clone --depth 1 --no-tags "$BASHUNIT_GIT_REPO" temp_bashunit 2>/dev/null
  cd temp_bashunit
  ./build.sh >/dev/null
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

  if command -v curl > /dev/null 2>&1; then
    curl -L -O -J "$BASHUNIT_GIT_REPO/releases/download/$TAG/bashunit" 2>/dev/null
  elif command -v wget > /dev/null 2>&1; then
    wget "$BASHUNIT_GIT_REPO/releases/download/$TAG/bashunit" 2>/dev/null
  else
    echo "Cannot download bashunit: curl or wget not found."
  fi
  chmod u+x "bashunit"
}

#########################
######### MAIN ##########
#########################

DIR=${1-lib}
VERSION=${2-latest}

BASHUNIT_GIT_REPO="https://github.com/TypedDevs/bashunit"
if is_git_installed; then
    LATEST_BASHUNIT_VERSION="$(get_latest_tag "$BASHUNIT_GIT_REPO")"
else
    LATEST_BASHUNIT_VERSION="0.19.1"
fi
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
