#!/bin/bash

# shellcheck disable=SC2164
# shellcheck disable=SC2103

DIR=${DIR-lib}

cd "$(dirname "$0")"
rm -f "$DIR"/bashunit
[ -d "$DIR" ] || mkdir "$DIR"
cd "$DIR"

TAG=${1-main}

if [[ $TAG == main ]]; then
  echo "> Using main branch"
  git clone https://github.com/TypedDevs/bashunit temp_bashunit
else
  echo "> Using a concrete tag '$TAG'"
  curl -L -O -J "https://github.com/TypedDevs/bashunit/archive/refs/tags/$TAG.tar.gz"
  tar -zxvf "bashunit-$TAG.tar.gz"
  cp "bashunit-$TAG/bin/bashunit" temp_bashunit
  rm "bashunit-$TAG.tar.gz"
fi

## Common
cd temp_bashunit
./build.sh
cd ..
cp temp_bashunit/bin/bashunit bashunit
rm -rf temp_bashunit
