#!/bin/bash

# shellcheck disable=SC2164
# shellcheck disable=SC2103

declare -r LATEST_BASHUNIT_VERSION="0.10.0"

DIR=${1-lib}
VERSION=${2-latest}
TAG="$LATEST_BASHUNIT_VERSION"

function build_and_install_beta() {
  echo "> Downloading non-stable version: 'beta'"
  git clone --depth 1 --no-tags https://github.com/TypedDevs/bashunit temp_bashunit 2>/dev/null
  cd temp_bashunit
  ./build.sh >/dev/null
  cd ..
  sed -i -e 's/BASHUNIT_VERSION=".*"/BASHUNIT_VERSION="(non-stable) beta"/g' temp_bashunit/bin/bashunit
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

  curl -L -O -J "https://github.com/TypedDevs/bashunit/releases/download/$TAG/bashunit" 2>/dev/null
  chmod u+x "bashunit"
}

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
