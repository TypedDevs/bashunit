#!/bin/bash

# shellcheck disable=SC2164
# shellcheck disable=SC2103

DIR=${1-lib}
TAG=${2-main}

cd "$(dirname "$0")"
rm -f "$DIR"/bashunit
[ -d "$DIR" ] || mkdir "$DIR"
cd "$DIR"

if [[ $TAG == main ]]; then
  echo "> Using main branch"
  git clone https://github.com/TypedDevs/bashunit temp_bashunit
  cd temp_bashunit
  ./build.sh
  cd ..
  cp temp_bashunit/bin/bashunit bashunit
  rm -rf temp_bashunit
else
  echo "> Using a concrete tag '$TAG'"
  curl -L -O -J "https://github.com/TypedDevs/bashunit/releases/download/$TAG/bashunit"
  chmod +x "bashunit"
fi
