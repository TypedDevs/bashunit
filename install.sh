#!/bin/bash

# shellcheck disable=SC2164
# shellcheck disable=SC2103

declare -r LATEST_BASHUNIT_VERSION="0.9.0"

DIR=${1-lib}
VERSION=${2-latest}
TAG="$LATEST_BASHUNIT_VERSION"

function install_main() {
  echo "> Downloading non-stable main"
  git clone --depth 1 --no-tags https://github.com/TypedDevs/bashunit temp_bashunit
  cd temp_bashunit
  ./build.sh
  cd ..
  cp temp_bashunit/bin/bashunit bashunit
  sed -i -e 's/BASHUNIT_VERSION=".*"/BASHUNIT_VERSION="(non-stable) main"/g' bashunit
  rm -rf temp_bashunit
  echo "> bashunit has been installed in the '$DIR' folder"
}

function install_concrete_version() {
  if [[ $VERSION != 'latest' ]]; then
    TAG="$VERSION"
    echo "> Downloading a concrete version: '$TAG'"
  else
    echo "> Downloading the latest version: '$TAG'"
  fi

  curl -L -O -J "https://github.com/TypedDevs/bashunit/releases/download/$TAG/bashunit" 2>/dev/null
  chmod u+x "bashunit"
  echo "> bashunit has been installed in the '$DIR' folder"
}

cd "$(dirname "$0")"
rm -f "$DIR"/bashunit
[ -d "$DIR" ] || mkdir "$DIR"
cd "$DIR"

if [[ $VERSION == 'main' ]]; then
  install_main
else
  install_concrete_version
fi

